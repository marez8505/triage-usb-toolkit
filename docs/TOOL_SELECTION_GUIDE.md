# Tool Selection Guide

Why each tool is in the toolkit, what its niche is, and what to
cross-validate it against. This is intentionally opinionated — adapt to
your jurisdiction, accreditation requirements, and the specifics of
each engagement.

## Selection principles

1. **Authority and intent.** Every tool here is used in current,
   *defensive* DFIR practice (incident response, fraud investigation,
   civil discovery, sworn examination). None are primarily offensive.
2. **Free / open-source preferred.** Closed-source tools are included
   only when there is a specific, well-known capability gap (FTK
   Imager for raw imaging) and the tool can be downloaded officially.
3. **Reproducibility.** Tools that produce parseable, hashable output
   are preferred. We bias toward CLI / scriptable workflows.
4. **Cross-validation.** For every artifact category we list two tools
   so a finding can be confirmed by an independent code path.
5. **Vendor stewardship.** Where a tool's license or terms restrict
   redistribution, we **link** to the official source rather than
   bundling.

## Windows

| Need | Primary | Cross-validate with |
|------|---------|---------------------|
| Triage collection | KAPE (with Targets/Modules) | Velociraptor offline collector |
| Registry parsing | EZ Tools `RECmd` | KAPE module output, Autopsy |
| MFT / journal | EZ Tools `MFTECmd` | Autopsy + TSK `fls` |
| Event logs | EZ Tools `EvtxECmd` | Hayabusa / Chainsaw |
| Prefetch / Amcache | EZ Tools `PECmd`, `AmcacheParser` | KAPE module output |
| Memory acquisition | WinPmem | (not cross-validated; preserve original) |
| Memory analysis | Volatility 3 | MemProcFS |
| Imaging | FTK Imager | Autopsy / `dd` over write-blocker |
| Live response (read-mostly) | `collect_windows_live_response.ps1` | Sysinternals (Autoruns, Process Explorer) |
| Threat hunting on logs | Hayabusa | Chainsaw |
| Timelines | Plaso (`log2timeline`/`psort`) | Autopsy timeline |

### Notes
- KAPE is **free for non-commercial / law enforcement** use; download
  per investigator. Read Kroll's licensing terms for commercial use.
- WinPmem and other memory acquisition tools modify a small amount of
  system state. Document this; do not consider it "non-invasive."

## macOS

| Need | Primary | Cross-validate with |
|------|---------|---------------------|
| Triage collection (live) | AutoMacTC | `mac_apt` against the live disk |
| Artifact parsing (offline) | `mac_apt` | Plaso |
| Persistence inventory | Objective-See KnockKnock | `launchctl list` + `launch_locations_listing` |
| Live process triage | Objective-See TaskExplorer | `ps`, `lsof -i -nP` |
| Live introspection queries | osquery | shell commands |
| Diagnostics bundle | `sysdiagnose` | (not cross-validated) |
| Unified logs | `log show` (built-in) | Plaso parsers |
| Quarantine events | `LSQuarantineEventV2` SQLite | mac_apt parser |

### Notes
- T2 / Apple Silicon hardware-encrypted storage means cold-boot
  imaging without owner credentials is generally not productive.
  Prefer live-host triage with explicit authority.
- Avoid installing the osquery daemon on a suspect host; use
  `osqueryi` for ad-hoc queries.

## Android

| Need | Primary | Cross-validate with |
|------|---------|---------------------|
| Acquisition (logical, with consent) | `adb` (Platform Tools) | MVT `check-adb` |
| Bugreport bundle | `adb bugreport` | dumpsys / logcat |
| Package list | `pm list packages` | dumpsys package |
| Targeted IOC scanning | MVT Android | (manual review of dumps) |
| Filesystem extraction parsing | ALEAPP | manual / SQLite queries |

### Notes
- This toolkit explicitly does **not** root the device or bypass the
  lock screen. If the device is locked and you do not have the
  passcode, document and transport to the lab.
- USB debugging must be enabled, and the host must be authorized on
  the device. The owner / authority must approve.

## iOS

| Need | Primary | Cross-validate with |
|------|---------|---------------------|
| Acquisition | `idevicebackup2 --full` (libimobiledevice) | Apple Configurator 2 / Finder backup |
| Targeted IOC scanning | MVT iOS (`mvt-ios check-backup`) | iLEAPP report |
| Backup decryption | `mvt-ios decrypt-backup` | Vendor tooling with the owner |
| Database review | DB Browser for SQLite | sqlite3 CLI on analyst host |

### Notes
- This toolkit explicitly does **not** jailbreak or exploit iOS.
- Encrypted backups contain richer artifacts than unencrypted backups.
  Always document the encryption password in the case file.
- Consent / lawful authority required (per Amnesty International
  Security Lab guidance for MVT).

## Cross-platform / analyst workstation

| Need | Primary | Cross-validate with |
|------|---------|---------------------|
| Image analysis GUI | Autopsy / Sleuth Kit | `mac_apt`, `ALEAPP`, `iLEAPP` per-platform |
| Cross-platform timeline | Plaso | tool-specific timelines (e.g. Autopsy timeline) |
| Endpoint DFIR | Velociraptor | tool-specific collectors |
| Reference data / methodology | NIST CFTT / CFReDS | vendor docs |

## When to skip a tool

- It hasn't been updated in years and has known parsing bugs against
  current OS versions.
- The license forbids your use case (e.g., commercial use of a
  non-commercial-only tool).
- Its primary purpose is offensive (this toolkit doesn't include such
  tools — don't add them).
- You can't explain its findings to a court / opposing examiner. If
  you can't defend the methodology, don't rely on it as a primary
  source.
