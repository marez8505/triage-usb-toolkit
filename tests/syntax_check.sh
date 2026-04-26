#!/usr/bin/env bash
# Cheap syntax checks for shell + PowerShell + JSON.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

echo "## bash -n on shell scripts"
while IFS= read -r -d '' f; do
  if bash -n "$f"; then
    echo "[ok]   $f"
  else
    echo "[FAIL] $f"; fail=1
  fi
done < <(find "$REPO_ROOT/scripts" "$REPO_ROOT/tests" -type f -name "*.sh" -print0)

if command -v shellcheck >/dev/null 2>&1; then
  echo "## shellcheck on shell scripts"
  while IFS= read -r -d '' f; do
    if shellcheck -x -S warning "$f"; then
      echo "[ok]   shellcheck $f"
    else
      echo "[WARN] shellcheck found issues in $f"
    fi
  done < <(find "$REPO_ROOT/scripts" "$REPO_ROOT/tests" -type f -name "*.sh" -print0)
else
  echo "[skip] shellcheck not installed"
fi

if command -v pwsh >/dev/null 2>&1; then
  echo "## PowerShell parse check"
  for f in "$REPO_ROOT/scripts/"*.ps1; do
    [[ -e "$f" ]] || continue
    if pwsh -NoProfile -Command "
        \$tokens=\$null; \$errors=\$null;
        [System.Management.Automation.Language.Parser]::ParseFile('$f', [ref]\$tokens, [ref]\$errors) | Out-Null;
        if (\$errors -and \$errors.Count -gt 0) { \$errors | ForEach-Object { Write-Error \$_ }; exit 1 } else { exit 0 }
      "; then
      echo "[ok]   pwsh parse $f"
    else
      echo "[FAIL] pwsh parse $f"; fail=1
    fi
  done
else
  echo "[skip] pwsh not installed; cannot syntax-check .ps1"
fi

echo "## JSON manifest validation"
bash "$REPO_ROOT/tests/validate_manifests.sh"

if (( fail != 0 )); then
  echo "[FAIL] syntax checks failed"; exit 1
fi
echo "[PASS] syntax checks"
