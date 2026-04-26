#!/usr/bin/env bash
# Validate manifest JSON files: must parse, have required fields, etc.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_DIR="$REPO_ROOT/manifests"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[FAIL] python3 is required to validate manifests" >&2
  exit 1
fi

python3 - "$MANIFEST_DIR" <<'PY'
import json, os, sys, pathlib
manifest_dir = pathlib.Path(sys.argv[1])
required_top = {"platform", "schema_version", "tools"}
required_tool = {
    "name", "category", "platform", "purpose", "official_url",
    "license", "redistribution", "install_method", "destination",
    "notes",
}
errors = []
files = sorted(manifest_dir.glob("*.json"))
if not files:
    print("[FAIL] no manifest JSON files found")
    sys.exit(1)
for f in files:
    try:
        data = json.loads(f.read_text(encoding="utf-8"))
    except Exception as e:
        errors.append(f"{f.name}: invalid JSON: {e}")
        continue
    missing = required_top - set(data.keys())
    if missing:
        errors.append(f"{f.name}: missing top-level keys: {sorted(missing)}")
    for i, tool in enumerate(data.get("tools", [])):
        miss = required_tool - set(tool.keys())
        if miss:
            errors.append(f"{f.name}: tool[{i}] '{tool.get('name','?')}' missing: {sorted(miss)}")
        if not str(tool.get("official_url","")).startswith(("http://","https://")):
            errors.append(f"{f.name}: tool[{i}] '{tool.get('name','?')}' invalid official_url")
    print(f"[ok] {f.name}: {len(data.get('tools', []))} tools")
if errors:
    print("\n[FAIL] manifest validation errors:")
    for e in errors:
        print("  - " + e)
    sys.exit(1)
print("\n[PASS] all manifests validated")
PY
