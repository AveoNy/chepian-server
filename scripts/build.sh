#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  printf '%s\n' 'build.sh: must be run as root' >&2
  exit 1
fi

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
cd "$repo_root"

log_file="$repo_root/build.log"
: > "$log_file"
exec > >(tee -a "$log_file") 2>&1

lb clean
lb config
lb build

source_iso="$repo_root/binary-hybrid.iso"
output_name="chepian-server-0.1.0-amd64.iso"
output_iso="$repo_root/$output_name"

if [[ ! -f "$source_iso" ]]; then
  printf '%s\n' "build.sh: expected ISO was not created: $source_iso" >&2
  exit 1
fi

mv -f -- "$source_iso" "$output_iso"
(cd "$repo_root" && sha256sum "$output_name" > "$output_name.sha256")
