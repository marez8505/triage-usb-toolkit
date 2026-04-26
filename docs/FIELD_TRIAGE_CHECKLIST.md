# Field Triage Checklist

A short, opinionated checklist for an authorized on-scene triage
engagement. Adapt it to your jurisdiction's standard operating
procedures. Always document deviations.

## 0. Before you go

- [ ] Confirm legal authority (warrant / consent / employer policy).
- [ ] Confirm scope: which devices, which custodians, what time window.
- [ ] Charge / verify your USB drive built from this toolkit. Verify the
      `logs/sha256_*.txt` against your master.
- [ ] Pack: write-blocker, evidence drives, anti-static bags, Faraday
      bag (mobile), cables (USB-A, USB-C, Lightning), power adapters,
      camera, gloves, tamper-evident seals, chain-of-custody forms,
      pens, label printer if available.
- [ ] Confirm the analyst workstation has the expected analysis tools
      installed (Autopsy, Plaso, MVT, iLEAPP, ALEAPP, etc.).

## 1. On scene — common steps

- [ ] **Photograph** the scene as found, including the screen state of
      every device.
- [ ] **Identify** each device (make, model, serial, IMEI/UDID where
      visible).
- [ ] **Time-sync note**: record device clock vs. wall clock vs. UTC.
- [ ] **Volatility decision**: if the device is on, decide whether to
      preserve volatile state (memory, network) or pull power.
- [ ] **Chain of custody** entry per device — see template.

## 2. PC / Windows

Order of operations:

- [ ] If the host is **on and authorized for live triage**:
  1. Insert the toolkit USB.
  2. Open an elevated PowerShell prompt **from the USB**, not the host.
  3. Run `collect_windows_live_response.ps1` writing to a separate
     evidence drive:
     ```powershell
     pwsh -NoProfile -ExecutionPolicy Bypass -File `
       <USB>\scripts\collect_windows_live_response.ps1 `
       -OutputRoot E:\evidence -CaseId <CASE> -IncludeEventLogs
     ```
  4. (Optional) Acquire memory with WinPmem (under authority; document).
  5. (Optional) Run KAPE with appropriate target/module modules.
- [ ] If the host is **off**:
  1. Photograph as found.
  2. Apply tamper-evident seal; transport to lab.
  3. Image with a hardware write-blocker (FTK Imager / Autopsy / dd).
- [ ] Hash all outputs and verify against the script's `sha256.txt`.

## 3. Mac / macOS

- [ ] If the Mac is **on and authorized for live triage**:
  1. Insert the toolkit USB. Open Terminal **from the USB**.
  2. Run:
     ```bash
     bash <USB>/scripts/collect_macos_live_response.sh \
       --output-root /Volumes/EVIDENCE \
       --case-id <CASE> \
       --unified-log-minutes 240
     ```
  3. (Optional) `--include-sysdiagnose` if you have sudo and authority.
  4. (Optional) Run AutoMacTC or `mac_apt` on the live mount.
- [ ] If the Mac is **off**:
  - Modern T2 / Apple Silicon Macs have hardware-encrypted storage. A
    cold image is unlikely to be useful without owner credentials.
    Document and transport for lab analysis under proper authority.

## 4. Android

- [ ] Confirm you have authority and (if practical) the owner's consent.
- [ ] If the device is locked and you do not have credentials, **stop**
      live collection. Photograph, place in Faraday bag, transport.
- [ ] If unlocked / authorized:
  1. Enable USB debugging (Settings → About → tap Build Number 7×;
      Settings → Developer Options → USB debugging).
  2. Connect to the analyst workstation; accept the RSA prompt.
  3. Run:
     ```bash
     bash scripts/collect_android_adb.sh \
       --output-root /Volumes/EVIDENCE \
       --case-id <CASE> \
       --bugreport
     ```
  4. (Optional) `mvt-android check-adb` for IOC scanning (with consent).
- [ ] Place the device in a Faraday bag when not actively collecting.

## 5. iOS

- [ ] Confirm authority and owner cooperation.
- [ ] If the device is locked and you do not have the passcode and the
      device is not in an unlocked, "Trust this computer" state, **stop**
      live collection. Document and transport.
- [ ] If unlocked / authorized:
  1. Connect via USB to a host with `libimobiledevice` installed.
  2. Tap "Trust" on the device.
  3. **Strongly recommended**: enable an encrypted backup password
     before backup. Document the password in the case file.
  4. Run:
     ```bash
     bash scripts/collect_ios_backup.sh \
       --output-root /Volumes/EVIDENCE \
       --case-id <CASE> \
       --encryption-password '<documented_password>'
     ```
  5. After backup, decrypt and analyze on the analyst workstation with
     MVT iOS or iLEAPP.
- [ ] Place the device in a Faraday bag when not collecting.

## 6. Wrap-up

- [ ] Verify all output hash files; copy hash files to a separate audit
      log.
- [ ] Seal evidence drives; complete chain-of-custody entries.
- [ ] Update [`CASE_NOTES_TEMPLATE.md`](CASE_NOTES_TEMPLATE.md) with the
      narrative.
- [ ] Re-image / wipe and rebuild the triage USB before the next case.
