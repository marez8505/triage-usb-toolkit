#!/usr/bin/env bash
# Smoke test: run build_usb.sh against a temp directory and assert that
# the expected layout, per-tool READMEs, inventory, and hash files were
# produced.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d -t triage-usb-smoke-XXXXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[info] tmp destination: $TMP_DIR"
bash "$REPO_ROOT/scripts/build_usb.sh" --destination "$TMP_DIR" --force >/dev/null

fail=0
expect_dir() {
  if [[ ! -d "$TMP_DIR/$1" ]]; then
    echo "[FAIL] expected dir missing: $1"; fail=1
  else
    echo "[ok]   dir: $1"
  fi
}
expect_file_glob() {
  # shellcheck disable=SC2086
  local matches=( $TMP_DIR/$1 )
  if [[ ! -e "${matches[0]}" ]]; then
    echo "[FAIL] expected file glob missing: $1"; fail=1
  else
    echo "[ok]   file: $1 -> ${matches[0]}"
  fi
}

for d in tools tools/win tools/mac tools/android tools/ios tools/common \
         scripts manifests docs cases evidence reports logs; do
  expect_dir "$d"
done

expect_file_glob "logs/build_usb_*.log"
expect_file_glob "logs/inventory_*.txt"
expect_file_glob "logs/sha256_*.txt"
expect_file_glob "logs/tool_index_*.tsv"

# A few per-tool READMEs that we expect from the manifests
for p in tools/win/kape/README.md \
         tools/win/ez_tools/README.md \
         tools/mac/mac_apt/README.md \
         tools/android/platform-tools/README.md \
         tools/ios/libimobiledevice/README.md \
         tools/common/plaso/README.md ; do
  if [[ -f "$TMP_DIR/$p" ]]; then
    echo "[ok]   tool readme: $p"
  else
    echo "[FAIL] missing tool readme: $p"; fail=1
  fi
done

# Top-level files
for f in README.md LICENSE SECURITY.md; do
  if [[ -f "$TMP_DIR/$f" ]]; then
    echo "[ok]   top-level: $f"
  else
    echo "[FAIL] missing top-level: $f"; fail=1
  fi
done

if (( fail != 0 )); then
  echo "[FAIL] smoke test failed"; exit 1
fi
echo "[PASS] smoke test"
