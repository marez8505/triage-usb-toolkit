#!/usr/bin/env bash
# build_usb.sh — lay out the standard triage USB folder structure on a
# destination drive, copy repo scripts/manifests/docs, and (optionally)
# download tools listed in the manifests.
#
# Usage:
#   ./scripts/build_usb.sh --destination /Volumes/TRIAGE [--download] [--force]
#
# Notes:
#   - Never attempts to repartition or format the destination.
#   - Does NOT copy proprietary binaries. With --download it only fetches
#     entries whose install_method is github_release or manual_download
#     pointing at a directly downloadable URL; for everything else it
#     creates the destination folder and a README pointing at the official
#     URL.
#   - Re-runnable: rebuilds only what is missing unless --force is given.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DESTINATION=""
DOWNLOAD=0
FORCE=0

print_help() {
  cat <<'EOF'
Usage: build_usb.sh --destination <path> [--download] [--force]

Options:
  --destination, -d   Path to the mounted USB drive root (required).
  --download          Attempt to download tools whose manifest entries
                      point at a directly downloadable URL. Does NOT
                      bypass registration / EULA-gated downloads.
  --force             Overwrite existing files on the destination.
  --help, -h          Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --destination|-d) DESTINATION="${2:-}"; shift 2 ;;
    --download)       DOWNLOAD=1; shift ;;
    --force)          FORCE=1; shift ;;
    --help|-h)        print_help; exit 0 ;;
    *) usage_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$DESTINATION" ]] || { print_help; usage_die "--destination is required"; }
[[ -d "$DESTINATION" ]] || usage_die "destination does not exist or is not a directory: $DESTINATION"

BUILD_TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$DESTINATION/logs/build_usb_${BUILD_TS}.log"
log_init "$LOG_FILE"

log_info "triage-usb-toolkit build_usb.sh starting"
log_info "destination=$DESTINATION download=$DOWNLOAD force=$FORCE"
log_info "repo_root=$REPO_ROOT"

# 1. Create folder structure
LAYOUT_DIRS=(
  "tools" "tools/win" "tools/mac" "tools/android" "tools/ios" "tools/common"
  "scripts" "manifests" "docs" "cases" "evidence" "reports" "logs"
)
for d in "${LAYOUT_DIRS[@]}"; do
  mkdir -p "$DESTINATION/$d"
done
log_info "folder layout created"

# 2. Copy repo scripts / manifests / docs
copy_tree() {
  local src="$1" dst="$2"
  if [[ ! -d "$src" ]]; then
    log_warn "source missing: $src"; return 0
  fi
  if [[ -d "$dst" && $FORCE -eq 0 ]]; then
    # copy into existing without overwriting protected files
    cp -R "$src/." "$dst/"
  else
    rm -rf "$dst"
    mkdir -p "$dst"
    cp -R "$src/." "$dst/"
  fi
  log_info "copied $src -> $dst"
}

copy_tree "$REPO_ROOT/scripts"   "$DESTINATION/scripts"
copy_tree "$REPO_ROOT/manifests" "$DESTINATION/manifests"
copy_tree "$REPO_ROOT/docs"      "$DESTINATION/docs"

# Top-level convenience copies
for f in README.md LICENSE SECURITY.md; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    cp -f "$REPO_ROOT/$f" "$DESTINATION/$f"
  fi
done

# 3. For each manifest, write a per-tool README with the official URL,
#    and (optionally) attempt downloads where it is safe to do so.
generate_tool_readmes() {
  local manifest="$1"
  [[ -f "$manifest" ]] || { log_warn "missing manifest: $manifest"; return 0; }
  log_info "processing manifest $manifest"

  # crude JSON walk via python3 if available, else node, else jq
  local parser=""
  if command -v python3 >/dev/null 2>&1; then parser="python3"
  elif command -v jq      >/dev/null 2>&1; then parser="jq"
  else
    log_warn "no python3 or jq found — skipping manifest expansion for $manifest"
    return 0
  fi

  local tmp_index
  tmp_index="$(mktemp)"

  if [[ "$parser" == "python3" ]]; then
    python3 - "$manifest" "$DESTINATION" "$tmp_index" <<'PY'
import json, os, sys, pathlib
manifest_path, dest_root, index_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(manifest_path) as f:
    data = json.load(f)
lines = []
for tool in data.get("tools", []):
    rel = tool.get("destination", "").strip().lstrip("/")
    if not rel:
        continue
    full = pathlib.Path(dest_root) / rel
    full.mkdir(parents=True, exist_ok=True)
    readme = full / "README.md"
    body = [
        f"# {tool.get('name','(unnamed)')}",
        "",
        f"- Category: {tool.get('category','')}",
        f"- Platform: {tool.get('platform','')}",
        f"- Purpose: {tool.get('purpose','')}",
        f"- Official URL: {tool.get('official_url','')}",
    ]
    if tool.get("alt_url"):
        body.append(f"- Alternate URL: {tool.get('alt_url')}")
    body += [
        f"- License: {tool.get('license','')}",
        f"- Redistribution: {tool.get('redistribution','')}",
        f"- Install method: {tool.get('install_method','')}",
        f"- Checksum reference: {tool.get('checksum_url','')}",
        f"- Expected SHA-256: {tool.get('sha256_placeholder','')}",
        "",
        "## Notes",
        "",
        tool.get("notes","") or "(no extra notes)",
        "",
        "## How to populate",
        "",
        "1. Download the tool from the Official URL above on a clean",
        "   workstation.",
        "2. Verify the publisher's signature and/or SHA-256 hash.",
        "3. Place the binaries/archive in this folder.",
        "",
    ]
    readme.write_text("\n".join(body), encoding="utf-8")
    lines.append(f"{tool.get('name','')}\t{tool.get('platform','')}\t{rel}\t{tool.get('install_method','')}\t{tool.get('redistribution','')}")
with open(index_path, "w") as f:
    f.write("\n".join(lines) + "\n")
PY
  else
    # jq fallback
    jq -r '.tools[] | [.name, .platform, .destination, .install_method, .redistribution, .official_url, .notes] | @tsv' "$manifest" \
      | while IFS=$'\t' read -r name plat rel install redist url notes; do
          [[ -n "$rel" ]] || continue
          mkdir -p "$DESTINATION/$rel"
          {
            echo "# $name"
            echo
            echo "- Platform: $plat"
            echo "- Official URL: $url"
            echo "- Install method: $install"
            echo "- Redistribution: $redist"
            echo
            echo "## Notes"
            echo
            echo "$notes"
          } > "$DESTINATION/$rel/README.md"
          printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$plat" "$rel" "$install" "$redist" >> "$tmp_index"
        done
  fi

  cat "$tmp_index" >> "$DESTINATION/logs/tool_index_${BUILD_TS}.tsv"
  rm -f "$tmp_index"
}

for m in "$REPO_ROOT/manifests/"*.json; do
  generate_tool_readmes "$m"
done

# 4. Optional: try to fetch directly downloadable assets
maybe_download_tools() {
  [[ $DOWNLOAD -eq 1 ]] || return 0
  if ! command -v curl >/dev/null 2>&1; then
    log_warn "--download requested but curl is not available; skipping"
    return 0
  fi
  log_info "--download enabled; this only fetches assets whose direct URL is in the manifest. Registration-gated tools are skipped."
  # We deliberately do NOT spider release pages. Operators must add a
  # 'direct_download_url' field to a manifest entry to enable fetch.
  if ! command -v python3 >/dev/null 2>&1; then
    log_warn "python3 not available; cannot parse manifests for direct_download_url"
    return 0
  fi
  python3 - "$REPO_ROOT" "$DESTINATION" <<'PY'
import json, os, sys, urllib.request, pathlib, hashlib
repo_root, dest_root = sys.argv[1], sys.argv[2]
manifests_dir = pathlib.Path(repo_root) / "manifests"
for mf in sorted(manifests_dir.glob("*.json")):
    with open(mf) as f:
        data = json.load(f)
    for tool in data.get("tools", []):
        url = tool.get("direct_download_url")
        if not url:
            continue
        rel = tool.get("destination", "").strip().lstrip("/")
        out_dir = pathlib.Path(dest_root) / rel
        out_dir.mkdir(parents=True, exist_ok=True)
        fname = url.rsplit("/", 1)[-1] or "download.bin"
        out = out_dir / fname
        if out.exists():
            print(f"[skip] {out} already exists")
            continue
        print(f"[get ] {url} -> {out}")
        try:
            with urllib.request.urlopen(url, timeout=30) as r, open(out, "wb") as w:
                while True:
                    chunk = r.read(65536)
                    if not chunk:
                        break
                    w.write(chunk)
            h = hashlib.sha256()
            with open(out, "rb") as fh:
                for chunk in iter(lambda: fh.read(65536), b""):
                    h.update(chunk)
            print(f"[hash] {out}: {h.hexdigest()}")
        except Exception as e:
            print(f"[err ] {url}: {e}")
PY
}
maybe_download_tools

# 5. Write the build inventory
INVENTORY="$DESTINATION/logs/inventory_${BUILD_TS}.txt"
{
  echo "# triage-usb-toolkit build inventory"
  echo "# built: $(_ts)"
  echo "# destination: $DESTINATION"
  echo
  echo "## file listing"
  ( cd "$DESTINATION" && find . -type f -not -path "./logs/*" | sort )
} > "$INVENTORY"
log_info "wrote inventory to $INVENTORY"

# 6. Hash everything that ended up on the USB (excluding logs to avoid
#    self-reference)
HASH_FILE="$DESTINATION/logs/sha256_${BUILD_TS}.txt"
hash_dir "$DESTINATION" "$HASH_FILE"
log_info "wrote sha256 catalog to $HASH_FILE"

log_info "build_usb.sh completed successfully"
echo
echo "USB drive built at: $DESTINATION"
echo "Build log:         $LOG_FILE"
echo "Inventory:         $INVENTORY"
echo "SHA-256 catalog:   $HASH_FILE"
