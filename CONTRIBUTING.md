# Contributing

Thanks for your interest in improving the Triage USB Toolkit. This project
is intentionally narrow in scope — we welcome contributions that make
**authorized** forensic triage faster, safer, or more reproducible.

## Scope

Contributions are welcome for:

- New manifest entries for free / open-source / officially-distributed
  tools used in current DFIR practice.
- Improvements to the collector scripts (Windows PowerShell, macOS Bash,
  Android `adb`, iOS `libimobiledevice`) — especially read-only commands,
  better logging, better hashing, better error handling.
- Documentation: clearer checklists, better legal/ethical guidance,
  better USB build / duplication procedures.
- Tests, linting, smoke tests, CI.

Contributions are **not** welcome for:

- Exploits, lock-screen bypass, jailbreak/root bypass, credential theft,
  password cracking, anti-forensic evasion, or persistence tooling.
- Redistribution of proprietary tools (KAPE, FTK Imager, etc.). Always
  link to the official source.
- Workflows that modify the source device beyond the minimum required.

## Process

1. Open an issue describing the change.
2. Fork the repo and create a feature branch.
3. Run `make validate` (JSON manifest validation + script syntax check).
4. If you have `shellcheck` and `pwsh`, run `make lint`.
5. Open a pull request. Include the official URL for any new tool you
   add to a manifest, and the redistribution status.

## Style

- Bash: targets `bash` (not `sh`); `set -euo pipefail`; pass `shellcheck`.
- PowerShell: `Set-StrictMode -Version Latest`; clean syntax under
  `pwsh -NoProfile -Command`.
- JSON manifests: valid JSON, sorted by `name` within each category.
- Docs: GitHub-flavored Markdown.

## DCO / sign-off

Sign your commits (`git commit -s`) to certify the
[Developer Certificate of Origin](https://developercertificate.org/).
