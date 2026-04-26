#!/usr/bin/env bash
# collect_macos_live_response.sh — read-only macOS triage collector for
# authorized triage. Collects benign system metadata; does NOT extract
# Keychain, secrets, or user file contents. Hashes every output file.
#
# Authorized use only. Run only with documented authority.
#
# Usage:
#   ./scripts/collect_macos_live_response.sh \
#       --output-root /Volumes/EVIDENCE \
#       --case-id CASE-2026-001 \
#       [--unified-log-minutes 60] \
#       [--include-sysdiagnose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

OUTPUT_ROOT=""
CASE_ID=""
UNIFIED_LOG_MINUTES=60
INCLUDE_SYSDIAGNOSE=0

print_help() {
  cat <<'EOF'
Usage: collect_macos_live_response.sh --output-root <path> --case-id <id> [options]

Options:
  --output-root, -o          Path under which a case folder is created.
  --case-id, -c              Case identifier (used for folder name).
  --unified-log-minutes, -m  Minutes of unified log to export (default 60).
  --include-sysdiagnose      Run `sysdiagnose -b` (large, requires sudo).
  --help, -h                 Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-root|-o)         OUTPUT_ROOT="${2:-}"; shift 2 ;;
    --case-id|-c)             CASE_ID="${2:-}";     shift 2 ;;
    --unified-log-minutes|-m) UNIFIED_LOG_MINUTES="${2:-}"; shift 2 ;;
    --include-sysdiagnose)    INCLUDE_SYSDIAGNOSE=1; shift ;;
    --help|-h)                print_help; exit 0 ;;
    *) usage_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$OUTPUT_ROOT" ]] || { print_help; usage_die "--output-root required"; }
[[ -n "$CASE_ID"     ]] || { print_help; usage_die "--case-id required"; }
[[ -d "$OUTPUT_ROOT" ]] || usage_die "output-root not found: $OUTPUT_ROOT"

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
CASE_DIR="$OUTPUT_ROOT/${CASE_ID}_${RUN_TS}"
OUT_DIR="$CASE_DIR/macos_live_response"
LOG_DIR="$CASE_DIR/logs"
mkdir -p "$OUT_DIR" "$LOG_DIR"

LOG_FILE="$LOG_DIR/collector.log"
CMD_LOG="$LOG_DIR/commands.tsv"
HASH_FILE="$LOG_DIR/sha256.txt"
log_init "$LOG_FILE"

{
  echo "# triage-usb-toolkit macOS live-response collector"
  echo "# started: $(_ts)"
  echo "# host: $(hostname 2>/dev/null || true)"
  echo "# user: $(whoami 2>/dev/null || true)"
  echo "# case: $CASE_ID"
  echo "# output: $OUT_DIR"
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

require_cmd sw_vers system_profiler scutil dscl ps launchctl netstat ifconfig log

# --- system ---------------------------------------------------------------
run_step "sw_vers"                "$OUT_DIR/sw_vers.txt"               sw_vers
run_step "uname -a"               "$OUT_DIR/uname.txt"                 uname -a
run_step "hostname"               "$OUT_DIR/hostname.txt"              hostname
run_step "scutil --get ComputerName" "$OUT_DIR/computer_name.txt"      scutil --get ComputerName
run_step "scutil --get LocalHostName" "$OUT_DIR/local_host_name.txt"   scutil --get LocalHostName
run_step "uptime"                 "$OUT_DIR/uptime.txt"                uptime
run_step "date (utc)"             "$OUT_DIR/date_utc.txt"              date -u
run_step "system_profiler SPHardwareDataType" "$OUT_DIR/sp_hardware.txt" system_profiler SPHardwareDataType
run_step "system_profiler SPSoftwareDataType" "$OUT_DIR/sp_software.txt" system_profiler SPSoftwareDataType
run_step "system_profiler SPNetworkDataType" "$OUT_DIR/sp_network.txt"   system_profiler SPNetworkDataType
run_step "system_profiler SPUSBDataType"     "$OUT_DIR/sp_usb.txt"       system_profiler SPUSBDataType

# --- users ---------------------------------------------------------------
run_step "dscl . list /Users"     "$OUT_DIR/users.txt"                 dscl . list /Users
run_step "dscl . list /Groups"    "$OUT_DIR/groups.txt"                dscl . list /Groups
run_step "who"                    "$OUT_DIR/who.txt"                   who
run_step "last -50"               "$OUT_DIR/last.txt"                  last -50

# --- processes ------------------------------------------------------------
run_step "ps auxww"               "$OUT_DIR/ps_auxww.txt"              ps auxww
run_step "ps -eo pid,ppid,user,lstart,command" "$OUT_DIR/ps_tree.txt" ps -eo pid,ppid,user,lstart,command

# --- launchd persistence (listings, not contents) ------------------------
run_step "launchctl list"         "$OUT_DIR/launchctl_list.txt"        launchctl list
{
  echo "## /Library/LaunchAgents"
  ls -la /Library/LaunchAgents 2>/dev/null || true
  echo
  echo "## /Library/LaunchDaemons"
  ls -la /Library/LaunchDaemons 2>/dev/null || true
  echo
  echo "## /System/Library/LaunchAgents"
  ls -la /System/Library/LaunchAgents 2>/dev/null || true
  echo
  echo "## /System/Library/LaunchDaemons"
  ls -la /System/Library/LaunchDaemons 2>/dev/null || true
  echo
  echo "## ~/Library/LaunchAgents"
  ls -la "$HOME/Library/LaunchAgents" 2>/dev/null || true
} > "$OUT_DIR/launch_locations_listing.txt" 2>>"$LOG_FILE"

# --- network --------------------------------------------------------------
run_step "ifconfig -a"            "$OUT_DIR/ifconfig.txt"              ifconfig -a
run_step "netstat -anv"           "$OUT_DIR/netstat.txt"               netstat -anv
run_step "netstat -rn"            "$OUT_DIR/netstat_rn.txt"            netstat -rn
run_step "arp -a"                 "$OUT_DIR/arp.txt"                   arp -a
run_step "scutil --dns"           "$OUT_DIR/scutil_dns.txt"            scutil --dns
if command -v lsof >/dev/null 2>&1; then
  run_step "lsof -i -nP"          "$OUT_DIR/lsof_network.txt"          lsof -i -nP
fi

# --- installed apps -------------------------------------------------------
run_step "system_profiler SPApplicationsDataType"  "$OUT_DIR/sp_applications.txt"  system_profiler SPApplicationsDataType
run_step "ls -la /Applications"                    "$OUT_DIR/applications_listing.txt" ls -la /Applications

# --- quarantine events (read-only via sqlite if available) ---------------
QEV_DB="$HOME/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$QEV_DB" ]]; then
  run_step "quarantine events" "$OUT_DIR/quarantine_events.tsv" \
    sqlite3 -header -separator $'\t' "$QEV_DB" \
      "SELECT LSQuarantineEventIdentifier, LSQuarantineTimeStamp, LSQuarantineAgentName, LSQuarantineAgentBundleIdentifier, LSQuarantineDataURLString, LSQuarantineOriginURLString FROM LSQuarantineEvent ORDER BY LSQuarantineTimeStamp DESC LIMIT 1000;"
else
  log_info "skipping quarantine events (sqlite3 missing or DB not present)"
fi

# --- shell history (metadata only, NOT contents) -------------------------
{
  for f in "$HOME/.bash_history" "$HOME/.zsh_history" "$HOME/.history"; do
    if [[ -f "$f" ]]; then
      stat -f '%N  size=%z  mtime=%Sm  uid=%u  mode=%Sp' "$f" 2>/dev/null \
        || stat -c '%n  size=%s  mtime=%y  uid=%u  mode=%A' "$f" 2>/dev/null \
        || ls -la "$f"
    fi
  done
} > "$OUT_DIR/shell_history_metadata.txt" 2>>"$LOG_FILE"

# --- unified log excerpt --------------------------------------------------
if command -v log >/dev/null 2>&1; then
  run_step "log show --last ${UNIFIED_LOG_MINUTES}m" \
    "$OUT_DIR/unified_log_last_${UNIFIED_LOG_MINUTES}m.txt" \
    log show --style syslog --last "${UNIFIED_LOG_MINUTES}m"
fi

# --- optional sysdiagnose -------------------------------------------------
if [[ $INCLUDE_SYSDIAGNOSE -eq 1 ]]; then
  if command -v sysdiagnose >/dev/null 2>&1; then
    log_info "running sysdiagnose -b -f $OUT_DIR (requires sudo)"
    if sudo -n true 2>/dev/null; then
      sudo sysdiagnose -b -f "$OUT_DIR" >>"$LOG_FILE" 2>&1 || \
        log_warn "sysdiagnose failed; continuing"
    else
      log_warn "sudo not available non-interactively; skipping sysdiagnose"
    fi
  else
    log_warn "sysdiagnose not present; skipping"
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
EOF
