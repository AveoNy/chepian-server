#!/usr/bin/env bash

chep_info() { printf '[INFO] %s\n' "$*"; }
chep_warn() { printf '[WARN] %s\n' "$*" >&2; }
chep_error() { printf '[FAIL] %s\n' "$*" >&2; }
chep_success() { printf '[ OK ] %s\n' "$*"; }
chep_command_exists() { command -v "$1" >/dev/null 2>&1; }
chep_require_command() {
  if ! chep_command_exists "$1"; then
    chep_error "required command is unavailable: $1"
    return 3
  fi
}
chep_require_root() {
  if (( EUID != 0 )); then
    chep_error 'this operation requires root privileges'
    return 1
  fi
}
chep_escalate() {
  if (( EUID == 0 )); then
    return 0
  fi
  if ! chep_command_exists sudo; then
    chep_error 'this operation requires root privileges and sudo is unavailable'
    return 1
  fi
  exec sudo -- "$@"
}
CHEP_TEMPDIR=""
chep_create_secure_tempdir() {
  local previous_umask tempdir
  previous_umask="$(umask)"
  umask 077
  if ! tempdir="$(mktemp -d "${TMPDIR:-/tmp}/chep.XXXXXXXX")"; then
    umask "$previous_umask"
    chep_error 'unable to create a secure temporary directory'
    return 1
  fi
  umask "$previous_umask"
  CHEP_TEMPDIR="$tempdir"
  printf '%s\n' "$CHEP_TEMPDIR"
}
chep_cleanup_tempdir() {
  if [[ -n "$CHEP_TEMPDIR" && -d "$CHEP_TEMPDIR" && "$CHEP_TEMPDIR" == "${TMPDIR:-/tmp}"/chep.* ]]; then
    rm -rf -- "$CHEP_TEMPDIR"
  fi
  CHEP_TEMPDIR=""
}
chep_human_bytes() {
  local bytes="$1" unit=0
  local -a units=(B KiB MiB GiB TiB)
  while (( bytes >= 1024 && unit < ${#units[@]} - 1 )); do
    bytes=$((bytes / 1024))
    unit=$((unit + 1))
  done
  printf '%s %s' "$bytes" "${units[$unit]}"
}
