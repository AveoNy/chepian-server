#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)"
lib="$repo_root/config/includes.chroot/usr/lib/chep"
# shellcheck source=../config/includes.chroot/usr/lib/chep/common.sh
source "$lib/common.sh"
# shellcheck source=../config/includes.chroot/usr/lib/chep/doctor.sh
source "$lib/doctor.sh"

redacted="$(printf '%s\n' 'password=example token: value api_key=key' | doctor_redact)"
[[ "$redacted" == *'password=[REDACTED]'* ]]
[[ "$redacted" == *'token: [REDACTED]'* ]]
[[ "$redacted" == *'api_key=[REDACTED]'* ]]

CHEP_DOCTOR_WARN=0; CHEP_DOCTOR_FAIL=0
set +e; doctor_result; rc=$?; set -e
[[ "$rc" == 0 ]]
CHEP_DOCTOR_WARN=1; CHEP_DOCTOR_FAIL=0
set +e; doctor_result; rc=$?; set -e
[[ "$rc" == 1 ]]
CHEP_DOCTOR_WARN=0; CHEP_DOCTOR_FAIL=1
set +e; doctor_result; rc=$?; set -e
[[ "$rc" == 2 ]]
if chep_doctor invalid >/dev/null 2>&1; then exit 1; else [[ $? == 3 ]]; fi
[[ "$(doctor_emit INFO piped)" != *$'\033['* ]]
uptime() { printf '\r\033[31mup 3 hours, 23 minutes'; }
uptime_output="$(doctor_uptime)"
[[ "$uptime_output" == '[INFO] uptime: up 3 hours, 23 minutes' ]]
[[ "$uptime_output" != *$'\r'* && "$uptime_output" != *$'\033['* ]]
archive_name='chep-doctor-20260101-000000.tar.gz'
[[ "$archive_name" =~ ^chep-doctor-[0-9]{8}-[0-9]{6}\.tar\.gz$ ]]

printf '%s\n' 'test-doctor.sh: passed'
