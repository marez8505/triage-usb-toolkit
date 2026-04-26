# Security policy

## Reporting a vulnerability

If you find a security issue in any script, manifest, or workflow in this
repository, please open a private security advisory via GitHub
("Security" → "Report a vulnerability") rather than filing a public issue.

Include:

- A description of the issue and impact (e.g., "the macOS collector
  writes to a path under the suspect's home directory").
- The script and line number.
- Steps to reproduce.
- Suggested fix, if any.

We aim to acknowledge reports within 5 business days.

## Out of scope

This repo intentionally does **not** ship offensive tooling. Reports of
"missing" exploits, bypasses, or anti-forensic features are out of scope
and will be closed.

## Hardening guidance for operators

- Always run collectors on a freshly built USB drive — do not reuse a
  drive that has been connected to a suspect host without re-imaging it.
- Verify the SHA-256 of every downloaded tool against the publisher's
  published hash before placing it on the USB.
- Keep an offline copy of your "golden" master USB image; rebuild from
  the master between cases.
- Treat collector output as evidence — write to a separate, encrypted
  evidence drive whenever possible, and hash on transfer.
