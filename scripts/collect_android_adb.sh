#!/usr/bin/env bash
# collect_android_adb.sh — Android triage helper using ADB.
#
# Authorized use only. Requires:
#   - lawful authority and/or owner consent
#   - Android device with USB debugging enabled
#   - the device authorizes this host for debugging (RSA fingerprint)
#
# This script does NOT bypass screen lock, root the device, or attempt
# to read private app data. It collects benign device metadata, package
# listings, and selected dumpsys excerpts.
#
# Usage:
#   ./scripts/collect_android_adb.sh \
#       --output-root /Volumes/EVIDENCE \
#       --case-id CASE-2026-001 \
#       [--bugreport]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

OUTPUT_ROOT=""
CASE_ID=""
INCLUDE_BUGREPORT=0
ADB_CMD="${ADB:-adb}"

print_help() {
  cat <<'EOF'
Usage: collect_android_adb.sh --output-root <path> --case-id <id> [--bugreport]

Options:
  --output-root, -o   Path under which a case folder is created.
  --case-id, -c       Case identifier (used for folder name).
  --bugreport         Also run `adb bugreport` (large; takes minutes).
  --help, -h          Show this help.

Environment:
  ADB                 Override the adb binary path (default: adb on PATH).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-root|-o) OUTPUT_ROOT="${2:-}"; shift 2 ;;
    --case-id|-c)     CASE_ID="${2:-}";     shift 2 ;;
    --bugreport)      INCLUDE_BUGREPORT=1; shift ;;
    --help|-h)        print_help; exit 0 ;;
    *) usage_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$OUTPUT_ROOT" ]] || { print_help; usage_die "--output-root required"; }
[[ -n "$CASE_ID"     ]] || { print_help; usage_die "--case-id required"; }
[[ -d "$OUTPUT_ROOT" ]] || usage_die "output-root not found: $OUTPUT_ROOT"

if ! command -v "$ADB_CMD" >/dev/null 2>&1; then
  usage_die "adb not found (set ADB env or install Android Platform Tools): $ADB_CMD"
fi

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
CASE_DIR="$OUTPUT_ROOT/${CASE_ID}_${RUN_TS}"
OUT_DIR="$CASE_DIR/android_adb"
LOG_DIR="$CASE_DIR/logs"
mkdir -p "$OUT_DIR" "$LOG_DIR"

LOG_FILE="$LOG_DIR/collector.log"
CMD_LOG="$LOG_DIR/commands.tsv"
HASH_FILE="$LOG_DIR/sha256.txt"
log_init "$LOG_FILE"

{
  echo "# triage-usb-toolkit Android adb collector"
  echo "# started: $(_ts)"
  echo "# host: $(hostname 2>/dev/null || true)"
  echo "# user: $(whoami 2>/dev/null || true)"
  echo "# case: $CASE_ID"
  echo "# adb: $($ADB_CMD version 2>&1 | head -n1)"
} >> "$LOG_FILE"

printf 'timestamp_utc\tdescription\toutput_file\texit_code\n' > "$CMD_LOG"

run_adb() {
  local desc="$1" out="$2"; shift 2
  local stamp; stamp="$(_ts)"
  log_info "adb $* -> $out"
  local rc=0
  if ! "$ADB_CMD" "$@" >"$out" 2>>"$LOG_FILE"; then rc=$?; fi
  printf '%s\t%s\t%s\t%s\n' "$stamp" "$desc" "$out" "$rc" >> "$CMD_LOG"
}

# Wait briefly for an authorized device.
log_info "waiting up to 30s for device authorization..."
( "$ADB_CMD" wait-for-device & sleep 30; kill $! 2>/dev/null || true ) >/dev/null 2>&1 || true

# --- enumerate devices ---------------------------------------------------
"$ADB_CMD" devices -l > "$OUT_DIR/adb_devices.txt" 2>>"$LOG_FILE" || true
DEVICE_LINE=$(grep -E "device " "$OUT_DIR/adb_devices.txt" | grep -v "List of devices" || true)
if [[ -z "$DEVICE_LINE" ]]; then
  log_warn "no authorized adb device detected. Please ensure USB debugging is enabled and the host is authorized on the device. Continuing — most subsequent commands will fail."
fi

# --- device properties ---------------------------------------------------
run_adb "getprop"          "$OUT_DIR/getprop.txt"        shell getprop
run_adb "build properties" "$OUT_DIR/build_props.txt"    shell cat /system/build.prop
run_adb "uname -a"         "$OUT_DIR/uname.txt"          shell uname -a
run_adb "uptime"           "$OUT_DIR/uptime.txt"         shell uptime
run_adb "date"             "$OUT_DIR/date.txt"           shell date

# --- packages ------------------------------------------------------------
run_adb "pm list packages -f" "$OUT_DIR/packages_all.txt"   shell pm list packages -f
run_adb "pm list packages -3" "$OUT_DIR/packages_third.txt" shell pm list packages -3
run_adb "pm list packages -s" "$OUT_DIR/packages_system.txt" shell pm list packages -s
run_adb "pm list packages -d" "$OUT_DIR/packages_disabled.txt" shell pm list packages -d
run_adb "pm list users"       "$OUT_DIR/users.txt"            shell pm list users
run_adb "pm list permissions -g" "$OUT_DIR/permissions_groups.txt" shell pm list permissions -g

# --- dumpsys (selective, summary-level) -----------------------------------
for svc in battery netstats wifi connectivity activity package usagestats device_policy; do
  run_adb "dumpsys $svc" "$OUT_DIR/dumpsys_${svc}.txt" shell dumpsys "$svc"
done

# --- network -------------------------------------------------------------
run_adb "ip addr"          "$OUT_DIR/ip_addr.txt"        shell ip addr
run_adb "ip route"         "$OUT_DIR/ip_route.txt"       shell ip route
run_adb "ss -tunap"        "$OUT_DIR/ss_tunap.txt"       shell ss -tunap

# --- external shared storage listing (no file contents) ------------------
run_adb "ls /sdcard (top-level)" "$OUT_DIR/sdcard_top.txt" shell ls -la /sdcard
run_adb "ls /sdcard/Download"     "$OUT_DIR/sdcard_download.txt" shell ls -la /sdcard/Download
run_adb "ls /sdcard/DCIM"         "$OUT_DIR/sdcard_dcim.txt"     shell ls -la /sdcard/DCIM

# --- logcat snapshot (recent only) ---------------------------------------
run_adb "logcat -d -t 5000" "$OUT_DIR/logcat_recent.txt" logcat -d -t 5000

# --- optional bugreport --------------------------------------------------
if [[ $INCLUDE_BUGREPORT -eq 1 ]]; then
  log_info "running adb bugreport (this may take several minutes)"
  if "$ADB_CMD" bugreport "$OUT_DIR/bugreport.zip" >>"$LOG_FILE" 2>&1; then
    printf '%s\t%s\t%s\t0\n' "$(_ts)" "adb bugreport" "$OUT_DIR/bugreport.zip" >> "$CMD_LOG"
  else
    log_warn "adb bugreport failed"
    printf '%s\t%s\t%s\t1\n' "$(_ts)" "adb bugreport" "$OUT_DIR/bugreport.zip" >> "$CMD_LOG"
  fi
fi

# --- hash all collected files --------------------------------------------
hash_dir "$OUT_DIR" "$HASH_FILE"

log_info "collector finished"

cat <<EOF

Collection complete.
Case dir:      $CASE_DIR
Collector log: $LOG_FILE
Command log:   $CMD_LOG
SHA-256 file:  $HASH_FILE

NOTE: For deeper, MVT-based analysis, use:
  mvt-android download-iocs
  mvt-android check-adb --output <dir>
See https://docs.mvt.re/ for guidance, and only run with consent.
EOF
