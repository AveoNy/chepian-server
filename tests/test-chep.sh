#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)"
chep="$repo_root/config/includes.chroot/usr/bin/chep"
lib="$repo_root/config/includes.chroot/usr/lib/chep"

CHEP_LIB_DIR="$lib" bash "$chep" version | grep -Fx 'Chepian Server chep 0.2.0-dev' >/dev/null
CHEP_LIB_DIR="$lib" bash "$chep" help | grep -F 'doctor' >/dev/null
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
if grep -R -q --include='*.sh' --include='chep' 'eval' "$lib" "$chep"; then
  exit 1
fi

printf '%s\n' 'test-chep.sh: passed'
