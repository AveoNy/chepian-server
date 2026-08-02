#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)"
lib="$repo_root/config/includes.chroot/usr/lib/chep"
source "$lib/common.sh"
source "$lib/doctor.sh"

redacted="$(printf '%s\n' 'password=example token: value api_key=key' | doctor_redact)"
[[ "$redacted" == *'password=[REDACTED]'* ]]
[[ "$redacted" == *'token: [REDACTED]'* ]]
[[ "$redacted" == *'api_key=[REDACTED]'* ]]

CHEP_DOCTOR_WARN=0; CHEP_DOCTOR_FAIL=0; doctor_result
CHEP_DOCTOR_WARN=1; CHEP_DOCTOR_FAIL=0; if doctor_result; then exit 1; else [[ $? == 1 ]]; fi
CHEP_DOCTOR_WARN=0; CHEP_DOCTOR_FAIL=1; if doctor_result; then exit 1; else [[ $? == 2 ]]; fi
if chep_doctor invalid >/dev/null 2>&1; then exit 1; else [[ $? == 3 ]]; fi
[[ "$(doctor_emit INFO piped)" != *$'\033['* ]]

printf '%s\n' 'test-doctor.sh: passed'
