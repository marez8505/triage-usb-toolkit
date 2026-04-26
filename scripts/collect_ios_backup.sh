#!/usr/bin/env bash
# collect_ios_backup.sh — iOS triage helper using libimobiledevice.
#
# Authorized use only. This script does NOT bypass passcodes,
# jailbreak, or exploit iOS. It uses the official libimobiledevice
# tooling (idevicebackup2) to create an iOS backup that the device
# owner / lawful authority has consented to.
#
# Best practice: enable an encrypted backup password BEFORE the backup
# (encrypted iOS backups contain richer artifacts: Keychain metadata,
# Health, call history, etc.). Document the password in the case file.
#
# Usage:
#   ./scripts/collect_ios_backup.sh \
#       --output-root /Volumes/EVIDENCE \
#       --case-id CASE-2026-001 \
#       [--encryption-password '...'] \
#       [--udid <device_udid>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

OUTPUT_ROOT=""
CASE_ID=""
ENC_PASSWORD=""
UDID=""

print_help() {
  cat <<'EOF'
Usage: collect_ios_backup.sh --output-root <path> --case-id <id> [options]

Options:
  --output-root, -o          Path under which a case folder is created.
  --case-id, -c              Case identifier (used for folder name).
  --encryption-password, -p  If supplied AND backup encryption is OFF on
                             the device, this script will enable it before
                             running the backup. Document this password in
                             the case file. If backup encryption is already
                             ON, you must use the device owner's existing
                             password — this script will not change it.
  --udid                     Specific device UDID (otherwise uses the
                             only connected device).
  --help, -h                 Show this help.

Required tools (install via package manager):
  ideviceinfo, idevicepair, idevicebackup2, idevicename
  (`brew install libimobiledevice` on macOS;
   `apt-get install libimobiledevice-utils libimobiledevice6` on Debian/Ubuntu)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-root|-o)         OUTPUT_ROOT="${2:-}";  shift 2 ;;
    --case-id|-c)             CASE_ID="${2:-}";      shift 2 ;;
    --encryption-password|-p) ENC_PASSWORD="${2:-}"; shift 2 ;;
    --udid)                   UDID="${2:-}";         shift 2 ;;
    --help|-h)                print_help; exit 0 ;;
    *) usage_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$OUTPUT_ROOT" ]] || { print_help; usage_die "--output-root required"; }
[[ -n "$CASE_ID"     ]] || { print_help; usage_die "--case-id required"; }
[[ -d "$OUTPUT_ROOT" ]] || usage_die "output-root not found: $OUTPUT_ROOT"

require_cmd ideviceinfo idevicepair idevicebackup2

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
CASE_DIR="$OUTPUT_ROOT/${CASE_ID}_${RUN_TS}"
OUT_DIR="$CASE_DIR/ios_backup"
META_DIR="$CASE_DIR/ios_metadata"
LOG_DIR="$CASE_DIR/logs"
mkdir -p "$OUT_DIR" "$META_DIR" "$LOG_DIR"

LOG_FILE="$LOG_DIR/collector.log"
CMD_LOG="$LOG_DIR/commands.tsv"
HASH_FILE="$LOG_DIR/sha256.txt"
log_init "$LOG_FILE"

UDID_ARG=()
if [[ -n "$UDID" ]]; then
  UDID_ARG=(-u "$UDID")
fi

{
  echo "# triage-usb-toolkit iOS backup collector"
  echo "# started: $(_ts)"
  echo "# host: $(hostname 2>/dev/null || true)"
  echo "# user: $(whoami 2>/dev/null || true)"
  echo "# case: $CASE_ID"
  echo "# udid: ${UDID:-(auto)}"
} >> "$LOG_FILE"

printf 'timestamp_utc\tdescription\toutput_file\texit_code\n' > "$CMD_LOG"

run_step() {
  local desc="$1" out="$2"; shift 2
  local stamp; stamp="$(_ts)"
  log_info "$desc"
  local rc=0
  if ! "$@" >"$out" 2>>"$LOG_FILE"; then rc=$?; fi
  printf '%s\t%s\t%s\t%s\n' "$stamp" "$desc" "$out" "$rc" >> "$CMD_LOG"
}

# --- pairing -------------------------------------------------------------
log_info "checking pairing status (the device may prompt 'Trust this computer')"
if ! idevicepair "${UDID_ARG[@]}" validate >>"$LOG_FILE" 2>&1; then
  log_warn "device not paired; attempting pair (user must accept on the device)"
  idevicepair "${UDID_ARG[@]}" pair >>"$LOG_FILE" 2>&1 || \
    log_warn "pairing failed; subsequent steps will fail until trusted"
fi

# --- device metadata -----------------------------------------------------
run_step "ideviceinfo" "$META_DIR/device_info.txt" ideviceinfo "${UDID_ARG[@]}"
run_step "idevice_id -l" "$META_DIR/connected_udids.txt" idevice_id -l
if command -v idevicename >/dev/null 2>&1; then
  run_step "idevicename" "$META_DIR/device_name.txt" idevicename "${UDID_ARG[@]}"
fi
if command -v ideviceactivation >/dev/null 2>&1; then
  log_info "ideviceactivation present; not invoked (read-only triage)"
fi
if command -v idevicediagnostics >/dev/null 2>&1; then
  run_step "idevicediagnostics ioregentry IOUSBHostDevice" \
    "$META_DIR/idevicediagnostics_ioreg.txt" \
    idevicediagnostics "${UDID_ARG[@]}" ioregentry IOUSBHostDevice || true
fi

# --- backup encryption setup --------------------------------------------
if [[ -n "$ENC_PASSWORD" ]]; then
  log_info "checking current backup encryption state via 'idevicebackup2 backup encryption' API"
  if idevicebackup2 "${UDID_ARG[@]}" encryption on "$ENC_PASSWORD" >>"$LOG_FILE" 2>&1; then
    log_info "enabled backup encryption with provided password (record this password in the case file)."
  else
    log_warn "could not enable backup encryption (it may already be enabled with a different password). Proceeding."
  fi
else
  log_info "no --encryption-password supplied. Recommended: enable an encrypted backup before running this script. Without encryption, several artifacts (Keychain metadata, Health, call history) will be omitted from the backup."
fi

# --- run the backup ------------------------------------------------------
log_info "starting full iOS backup -> $OUT_DIR"
if idevicebackup2 "${UDID_ARG[@]}" backup --full "$OUT_DIR" >>"$LOG_FILE" 2>&1; then
  printf '%s\t%s\t%s\t0\n' "$(_ts)" "idevicebackup2 backup --full" "$OUT_DIR" >> "$CMD_LOG"
  log_info "backup completed"
else
  printf '%s\t%s\t%s\t1\n' "$(_ts)" "idevicebackup2 backup --full" "$OUT_DIR" >> "$CMD_LOG"
  log_warn "backup failed; see log for details"
fi

# --- hash backup contents (large) ---------------------------------------
log_info "hashing backup contents (this can take a while for large devices)"
hash_dir "$CASE_DIR" "$HASH_FILE"

log_info "collector finished"

cat <<EOF

Collection complete.
Case dir:      $CASE_DIR
Backup root:   $OUT_DIR
Metadata:      $META_DIR
Collector log: $LOG_FILE
Command log:   $CMD_LOG
SHA-256 file:  $HASH_FILE

NEXT STEPS (analyst workstation, with authority):
  - Decrypt the backup if needed (with the documented password) and
    analyze using MVT iOS or iLEAPP:
      mvt-ios decrypt-backup -p '<password>' -d <decrypted_dir> $OUT_DIR
      mvt-ios check-backup -o <report_dir> <decrypted_dir>
  - See https://docs.mvt.re/ for full guidance.
EOF
