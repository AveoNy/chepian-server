#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)"
chep="$repo_root/config/includes.chroot/usr/bin/chep"
lib="$repo_root/config/includes.chroot/usr/lib/chep"

CHEP_LIB_DIR="$lib" bash "$chep" version | grep -Fx 'Chepian Server chep 0.1.1' >/dev/null
CHEP_LIB_DIR="$lib" bash "$chep" help | grep -F 'doctor' >/dev/null
if CHEP_LIB_DIR="$lib" bash "$chep" help | grep -Eqi 'profile|bundle'; then
  exit 1
fi
if CHEP_LIB_DIR="$lib" bash "$chep" unknown >/dev/null 2>&1; then
  exit 1
else
  [[ $? == 2 ]]
fi
if CHEP_LIB_DIR="$lib" bash "$chep" install >/dev/null 2>&1; then
  exit 1
else
  [[ $? == 2 ]]
fi
for unsupported_command in profile bundle; do
  if CHEP_LIB_DIR="$lib" bash "$chep" "$unsupported_command" >/dev/null 2>&1; then
    exit 1
  else
    [[ $? == 2 ]]
  fi
done
if grep -R -q --include='*.sh' --include='chep' 'eval' "$lib" "$chep"; then
  exit 1
fi

printf '%s\n' 'test-chep.sh: passed'
