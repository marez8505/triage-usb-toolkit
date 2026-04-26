# Triage USB Toolkit

A reproducible, **authorized-use-only** digital forensics triage USB toolkit
covering Windows, macOS, iOS, and Android devices. The repository contains:

- Build scripts that lay out a standard triage USB drive on Windows or
  Linux/macOS hosts, so an investigator can quickly produce multiple
  identical drives.
- Tool **manifests** (no proprietary binaries are redistributed) that list
  the recommended free / open-source / officially-distributed tools, their
  purpose, official download URL, license / redistribution status, and
  install method.
- Read-only **live-response collector scripts** for Windows, macOS, Android
  (via `adb`), and iOS (via `libimobiledevice`) that gather benign system
  metadata and write a hashed, logged output package.
- Documentation: field-triage checklist, chain-of-custody template, case
  notes template, USB duplication guide, legal/ethical use guide, and tool
  selection guide.

> ⚠️ **Authorized use only.** This toolkit is intended for incident
> responders, sworn examiners, corporate IR teams, academic instruction,
> and consented personal-device triage. Read
> [`docs/LEGAL_AND_ETHICAL_USE.md`](docs/LEGAL_AND_ETHICAL_USE.md) **before**
> using any script. You must have lawful authority (warrant, employer
> policy, written consent, etc.) to triage any device.

---

## Design principles

1. **Authorized use only.** No exploits, credential theft, lock-screen
   bypass, jailbreak/root bypass, evasion, or persistence tooling are
   shipped or referenced as supported workflows.
2. **Read-only first.** Collectors prefer non-modifying commands. When a
   command must run elevated, the script logs that fact.
3. **Preserve evidence.** Every collector hashes its outputs (SHA-256) and
   appends to a per-run command log. Originals are never modified.
4. **No proprietary redistribution.** The repo contains *only* manifests,
   download scripts, links, and our own MIT-licensed code. Operators
   download the tools themselves from the official source.
5. **Reproducible.** `scripts/build_usb.{ps1,sh}` lays out the same folder
   structure on every drive, so investigators see a familiar layout.
6. **Documented.** Every collector run produces logs, hashes, and an
   inventory; every USB build produces an inventory file.

---

## Repository layout

```
.
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── SECURITY.md
├── Makefile
├── manifests/
│   ├── tools.common.json
│   ├── tools.windows.json
│   ├── tools.macos.json
│   ├── tools.android.json
│   └── tools.ios.json
├── scripts/
│   ├── build_usb.ps1                  # Windows USB layout builder
│   ├── build_usb.sh                   # Linux/macOS USB layout builder
│   ├── collect_windows_live_response.ps1
│   ├── collect_macos_live_response.sh
│   ├── collect_android_adb.sh
│   ├── collect_ios_backup.sh
│   └── lib/
│       └── common.sh                  # Shared bash helpers (logging, hashing)
├── docs/
│   ├── FIELD_TRIAGE_CHECKLIST.md
│   ├── CHAIN_OF_CUSTODY_TEMPLATE.md
│   ├── CASE_NOTES_TEMPLATE.md
│   ├── USB_DUPLICATION_GUIDE.md
│   ├── LEGAL_AND_ETHICAL_USE.md
│   └── TOOL_SELECTION_GUIDE.md
└── tests/
    ├── smoke_build_usb.sh
    └── validate_manifests.sh
```

When `scripts/build_usb.{ps1,sh}` runs, the destination drive is laid out
as:

```
<USB>/
├── tools/        # tool binaries (downloaded by operator, not committed)
├── scripts/      # copies of repo scripts
├── manifests/    # copies of repo manifests
├── docs/         # copies of repo docs (read-only reference)
├── cases/        # per-case working folders (created by operator)
├── evidence/     # hashed evidence outputs
├── reports/      # final reports
└── logs/         # build & collection logs, inventory, hashes
```

---

## Quick start

### 1. Clone

```bash
git clone https://github.com/marez8505/triage-usb-toolkit.git
cd triage-usb-toolkit
```

### 2. Read the legal/ethical guide

[`docs/LEGAL_AND_ETHICAL_USE.md`](docs/LEGAL_AND_ETHICAL_USE.md) — required.

### 3. Build a USB

Linux / macOS:

```bash
./scripts/build_usb.sh --destination /Volumes/TRIAGE
```

Windows PowerShell (run as Administrator only if your destination requires
it):

```powershell
.\scripts\build_usb.ps1 -Destination E:\
```

### 4. Download tools

Each manifest entry lists the official URL and the destination folder
inside `tools/`. Download from the official source on a clean workstation,
verify the publisher's signature/hash where available, and place the file
in the indicated subfolder.

### 5. Triage

Use the appropriate collector script for the target platform. See
[`docs/FIELD_TRIAGE_CHECKLIST.md`](docs/FIELD_TRIAGE_CHECKLIST.md) for the
recommended order of operations.

---

## Tool catalog

All tools below are referenced by manifest only — none are redistributed
in this repo. Always download from the official source.

### Windows / PC (`manifests/tools.windows.json`)

| Tool | Category | Purpose | Source | Redistribution |
|------|----------|---------|--------|----------------|
| KAPE (Kroll Artifact Parser and Extractor) | Triage collection & parsing | Modular Windows triage collection and processing of forensic artifacts. | <https://www.kroll.com/en/services/cyber/incident-response-recovery/kroll-artifact-parser-and-extractor-kape> | Free for non-commercial / law enforcement use; **registration required**. Do **not** redistribute — download per investigator. |
| Eric Zimmerman's EZ Tools | Artifact parsers | Suite of CLI parsers (MFTECmd, RECmd, PECmd, EvtxECmd, AmcacheParser, etc.) used for Windows artifact analysis and cross-validation. | <https://www.sans.org/tools/ez-tools/> / <https://ericzimmerman.github.io/> | Free; download from the official site. |
| Autopsy / The Sleuth Kit | Full forensic platform | GUI digital forensics platform / TSK CLI for image analysis, keyword search, timeline, and file carving. | <https://www.sleuthkit.org/autopsy/> | Open source (Apache 2.0 / IBM CPL). Redistribution allowed under license. |
| Velociraptor (offline collector) | Endpoint DFIR | Build a single-binary offline collector to gather custom artifacts from Windows hosts. | <https://www.rapid7.com/products/velociraptor/> / <https://docs.velociraptor.app/> | Open source (AGPL). |
| Volatility 3 | Memory forensics | Analyze captured memory images. | <https://www.volatilityfoundation.org/> | Open source. |
| WinPmem (via MemProcFS / Volatility) | Memory acquisition | Acquire physical memory from a live Windows host. | <https://github.com/Velocidex/WinPmem> | Open source (Apache 2.0). Use only with authority. |
| MemProcFS | Memory analysis | Mounts a memory image as a virtual filesystem for triage. | <https://github.com/ufrisk/MemProcFS> | Open source. |
| Hayabusa | Event log triage | Fast Windows event-log threat-hunting and triage. | <https://github.com/Yamato-Security/hayabusa> | Open source (GPL). |
| Chainsaw | Event log triage | Sigma-based Windows event-log searching and detection. | <https://github.com/WithSecureLabs/chainsaw> | Open source. |
| Plaso / log2timeline | Timeline analysis | Build super-timelines from collected artifacts; produces `.plaso` storage files. | <https://plaso.readthedocs.io/> | Open source (Apache 2.0). |
| Sysinternals Suite | Live response | `Autoruns`, `Process Explorer`, `Handle`, `Sigcheck`, etc. — read-mostly diagnostic utilities. | <https://learn.microsoft.com/en-us/sysinternals/> | Free from Microsoft; redistribution per Sysinternals EULA. |
| FTK Imager (Lite) | Imaging | Create forensic images and verified copies; preview filesystems. | <https://www.exterro.com/ftk-imager> | Free; **registration / manual download** required. Do not redistribute. |

### macOS (`manifests/tools.macos.json`)

| Tool | Category | Purpose | Source | Redistribution |
|------|----------|---------|--------|----------------|
| `mac_apt` | Triage parsing | macOS Artifact Parsing Tool — parses live disks, images, and `.tar` collections. | <https://github.com/ydkhatri/mac_apt> | Open source (MIT). |
| AutoMacTC | Triage collection | Automated macOS triage collection and parsing. | <https://github.com/CrowdStrike/automactc> | Open source (Apache 2.0). |
| Objective-See tools (KnockKnock, BlockBlock, LuLu, TaskExplorer) | Persistence / live response | Read-only inspection of persistence locations and running processes. | <https://objective-see.org/tools.html> | Free; download from official site. |
| osquery | Live response | SQL-based host introspection — useful for triage queries on live macOS. | <https://osquery.io/> | Open source (Apache 2.0). |
| Velociraptor (macOS collector) | Endpoint DFIR | Targeted artifact collection on macOS endpoints. | <https://docs.velociraptor.app/> | Open source (AGPL). |
| Plaso / log2timeline | Timeline analysis | Build super-timelines from macOS artifacts. | <https://plaso.readthedocs.io/> | Open source. |
| `sysdiagnose` (built-in) | Diagnostics | Apple's official diagnostic bundle (`sudo sysdiagnose`). Run only with authority. | Built into macOS | N/A |
| `log show` (built-in) | Unified log review | Stream/export Apple unified logs for the relevant time window. | Built into macOS | N/A |

### Android (`manifests/tools.android.json`)

| Tool | Category | Purpose | Source | Redistribution |
|------|----------|---------|--------|----------------|
| Android Platform Tools (`adb`) | Acquisition | Official ADB / `fastboot` from Google. Required for any `adb`-based collection. | <https://developer.android.com/tools/releases/platform-tools> | Free, redistributable per Google's terms (download per investigator). |
| MVT (Mobile Verification Toolkit) — Android | Targeted forensics | Consensual forensic analysis of Android devices for indicators of compromise. | <https://github.com/mvt-project/mvt> / <https://docs.mvt.re/> | Open source (MVT License). |
| ALEAPP | Artifact parsing | Android Logs Events And Protobuf Parser — parses ADB / filesystem extractions. | <https://github.com/abrignoni/ALEAPP> | Open source (MIT). |
| DB Browser for SQLite | Database review | View SQLite databases extracted from Android (with authority). | <https://sqlitebrowser.org/> | Open source (MPL/GPL). |

### iOS (`manifests/tools.ios.json`)

| Tool | Category | Purpose | Source | Redistribution |
|------|----------|---------|--------|----------------|
| `libimobiledevice` (incl. `idevicebackup2`, `ideviceinfo`) | Acquisition | Create iOS backups (encrypted recommended) and read device metadata over USB. | <https://libimobiledevice.org/> / <https://docs.mvt.re/en/latest/ios/backup/libimobiledevice/> | Open source (LGPL/GPL). |
| MVT (Mobile Verification Toolkit) — iOS | Targeted forensics | Consensual forensic analysis of iOS backups / file-system dumps. | <https://github.com/mvt-project/mvt> / <https://docs.mvt.re/> | Open source. |
| iLEAPP | Artifact parsing | iOS Logs Events And Protobuf Parser — parses iOS backups and extractions. | <https://github.com/abrignoni/iLEAPP> | Open source (MIT). |
| Apple Configurator 2 / Finder / iTunes | Backup workflow | Native, owner-controlled encrypted backup. Note encryption password in case file. | <https://support.apple.com/guide/iphone/back-up-iphone-iph3ecf67d29/ios> | Vendor tool, not redistributed. |
| DB Browser for SQLite | Database review | View SQLite databases inside an iOS backup (with authority). | <https://sqlitebrowser.org/> | Open source. |

### Common / cross-platform (`manifests/tools.common.json`)

| Tool | Purpose | Source |
|------|---------|--------|
| Plaso / log2timeline | Cross-platform timeline analysis | <https://plaso.readthedocs.io/> |
| Velociraptor offline collectors | Cross-platform endpoint collection | <https://docs.velociraptor.app/> |
| osquery | Cross-platform host introspection | <https://osquery.io/> |
| Autopsy / Sleuth Kit | Cross-platform image analysis | <https://www.sleuthkit.org/autopsy/> |

> A more detailed selection rationale per tool lives in
> [`docs/TOOL_SELECTION_GUIDE.md`](docs/TOOL_SELECTION_GUIDE.md).

---

## Forensic cautions

- Connect target storage through a **hardware write-blocker** when imaging
  raw disks. The collectors in this repo do **not** image disks — they
  collect benign live-response metadata only.
- Document **everything**: who, what, where, when, why, how. Use
  [`docs/CHAIN_OF_CUSTODY_TEMPLATE.md`](docs/CHAIN_OF_CUSTODY_TEMPLATE.md).
- Hash collected outputs immediately and again on transfer.
- Treat suspect devices as hostile environments — run collectors from the
  USB, write to a separate evidence drive when possible, and never run
  unknown binaries from the suspect device.
- For mobile devices, prefer **owner-supplied passcodes / backup
  passwords**. This toolkit does **not** bypass authentication.

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Pull requests must keep the
project free of offensive tooling, exploits, and proprietary binaries.

## Reporting security issues

See [`SECURITY.md`](SECURITY.md).

## License

MIT for the code/scripts/docs in this repo. Each third-party tool is
governed by its own license — check the manifest entry.
