# USB Duplication Guide

How to produce many identical triage USB drives reproducibly.

## 1. Prepare a "master" USB

1. **Pick a quality drive.** USB 3.x, 64 GB+ recommended (some
   collected outputs are large). Note the make/model so you can re-buy
   identical drives.
2. **Clean / format the drive** on a trusted workstation.
   - Windows: `diskpart` → `clean` → `create partition primary` →
     `format fs=exfat quick label=TRIAGE`. Use exFAT for cross-platform
     compatibility, or NTFS if you only deploy on Windows.
   - macOS / Linux: erase to exFAT or APFS/ext4 depending on your
     analyst environment.
3. **Build the layout** with the repo build script, from a clone of
   `triage-usb-toolkit`:
   - Linux/macOS:
     ```bash
     ./scripts/build_usb.sh --destination /Volumes/TRIAGE
     ```
   - Windows PowerShell:
     ```powershell
     .\scripts\build_usb.ps1 -Destination E:\
     ```
4. **Download the tools** listed in the manifests from each official
   source. Place each into the corresponding folder under
   `tools/<platform>/<tool>/`. Verify the publisher's signature and/or
   SHA-256 hash before placing the file.
5. **Record the master SHA-256 catalog**:
   - The build script wrote one to `<USB>/logs/sha256_<ts>.txt`. After
     adding tool downloads, regenerate:
     - Linux/macOS: `find <USB> -type f -not -path '*/logs/*' -print0 |
       xargs -0 sha256sum > master_sha256.txt`
     - PowerShell:
       ```powershell
       Get-ChildItem -Path E:\ -Recurse -File `
         | Where-Object { $_.FullName -notlike '*\logs\*' } `
         | ForEach-Object { (Get-FileHash -Algorithm SHA256 $_.FullName).Hash + '  ' + $_.FullName } `
         > master_sha256.txt
       ```
6. **Eject and label** the master drive: case-insensitive label,
   physical sticker, tamper-evident seal if appropriate.

## 2. Cloning approach

Two options:

### A. Logical clone (recommended for cross-platform)

Re-run the build script against each new drive, then copy the tool
binaries from the master:

```bash
./scripts/build_usb.sh --destination /Volumes/TRIAGE2
rsync -av --delete /Volumes/TRIAGE/tools/ /Volumes/TRIAGE2/tools/
```

Verify by computing a SHA-256 catalog on the new drive and `diff` it
against `master_sha256.txt` (paths normalized to relative).

This approach is filesystem-agnostic — useful when your kit needs to
run on Windows, macOS, and Linux.

### B. Block-level clone (Linux only, identical drives only)

Only when source and destination drives are the **same model** and
**same capacity**:

```bash
# Replace /dev/sdX (master) and /dev/sdY (target) with the actual
# device nodes. Triple-check with `lsblk` first.
sudo dd if=/dev/sdX of=/dev/sdY bs=4M status=progress conv=fsync
sudo sync
```

Verify with `sha256sum` on each drive's block device:

```bash
sudo sha256sum /dev/sdX /dev/sdY
```

> ⚠️ `dd` is destructive. Confirm device nodes. Do not run this on a
> mac with the master mounted as the boot device.

## 3. Verification per drive

For every produced drive:

- [ ] Mount, then `find ... -print0 | xargs -0 sha256sum` (or
      PowerShell equivalent).
- [ ] `diff` against `master_sha256.txt`.
- [ ] Confirm `scripts/build_usb.sh` is executable and runs `--help`.
- [ ] Confirm `scripts/collect_*.sh` are executable and run `--help`.
- [ ] Apply tamper-evident seal and label.

## 4. Field rotation

- Use a different drive per case if practical. After a case:
  1. Image the drive (full block-level image to your evidence store
     for audit).
  2. Wipe the drive on a clean workstation.
  3. Rebuild from master per section 1.
- Keep the master offline. Treat it like a code signing key.

## 5. Naming convention suggestion

```
TRIAGE-<KIT-VERSION>-<DRIVE-SERIAL-LAST4>
e.g. TRIAGE-2026.04-A1B2
```

Record the kit version (date or repo tag) and last 4 of the drive
serial on the physical label and in your kit register.
