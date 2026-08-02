#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  printf '%s\n' 'clean.sh: must be run as root' >&2
  exit 1
fi

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
cd "$repo_root"

lb clean --purge
