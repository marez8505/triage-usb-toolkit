#!/usr/bin/env bash
# Shared helpers for triage-usb-toolkit Bash scripts.
# Source this file from another script: `source "$(dirname "$0")/lib/common.sh"`
# shellcheck shell=bash

set -euo pipefail

# --- logging -----------------------------------------------------------------

LOG_FILE="${LOG_FILE:-}"

_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log_init() {
  # log_init <log_file>
  LOG_FILE="$1"
  mkdir -p "$(dirname "$LOG_FILE")"
  : > "$LOG_FILE"
  log_info "log initialized at $LOG_FILE"
}

_log() {
  local level="$1"; shift
  local msg="[$(_ts)] [$level] $*"
  echo "$msg"
  if [[ -n "$LOG_FILE" ]]; then
    echo "$msg" >> "$LOG_FILE"
  fi
}

log_info()  { _log "INFO"  "$@"; }
log_warn()  { _log "WARN"  "$@"; }
log_error() { _log "ERROR" "$@"; }

# --- command runner with logging --------------------------------------------

# run_logged <output_file> <command...>
# Runs the command, captures stdout to <output_file>, captures stderr into the log,
# and records the command line and exit status in the log.
run_logged() {
  local out_file="$1"; shift
  mkdir -p "$(dirname "$out_file")"
  log_info "RUN: $* > $out_file"
  local rc=0
  if ! "$@" >"$out_file" 2>>"${LOG_FILE:-/dev/null}"; then
    rc=$?
    log_warn "command exited with rc=$rc: $*"
  fi
  return 0  # never abort the collector on a single command failure
}

# --- hashing -----------------------------------------------------------------

# pick a SHA-256 implementation
_sha256_cmd=""
_pick_sha256() {
  if [[ -n "$_sha256_cmd" ]]; then return 0; fi
  if command -v sha256sum >/dev/null 2>&1; then
    _sha256_cmd="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    _sha256_cmd="shasum -a 256"
  else
    log_warn "no sha256sum or shasum available — hashes will be skipped"
    _sha256_cmd=""
  fi
}

# hash_dir <directory> <output_hash_file>
hash_dir() {
  _pick_sha256
  local dir="$1" out="$2"
  if [[ -z "$_sha256_cmd" ]]; then
    log_warn "skipping hash_dir for $dir"
    return 0
  fi
  log_info "hashing files under $dir -> $out"
  ( cd "$dir" && find . -type f ! -path "./$(basename "$out")" -print0 \
      | xargs -0 $_sha256_cmd ) > "$out" 2>>"${LOG_FILE:-/dev/null}" || true
}

# require_cmd <name> [<name> ...]
# Logs missing commands but does NOT abort.
require_cmd() {
  local missing=()
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      missing+=("$c")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    log_warn "missing tools (this script will skip those steps): ${missing[*]}"
  fi
}

# --- argument helpers --------------------------------------------------------

usage_die() {
  echo "$1" >&2
  exit 2
}
