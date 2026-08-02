#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"

source_dir="/usr/share/live/build/bootloaders"
target_dir="$repo_root/config/bootloaders"
splash_source="$repo_root/assets/chepian-splash.png"
splash_target="$target_dir/syslinux_common/splash.png"
default_splash="$target_dir/syslinux_common/splash.svg"

if [[ ! -d "$source_dir" ]]; then
  printf '%s\n' "prepare-branding.sh: live-build bootloader templates not found: $source_dir" >&2
  exit 1
fi

if [[ ! -f "$splash_source" ]]; then
  printf '%s\n' "prepare-branding.sh: splash image not found: $splash_source" >&2
  exit 1
fi

if [[ -L "$target_dir" ]]; then
  printf '%s\n' "prepare-branding.sh: config/bootloaders itself must not be a symbolic link" >&2
  exit 1
fi

mkdir -p -- "$target_dir"

find "$target_dir" -mindepth 1 -depth -delete

cp -a -- "$source_dir/." "$target_dir/"

mkdir -p -- "$target_dir/syslinux_common"

cp -- "$splash_source" "$splash_target"
chmod 0644 "$splash_target"

rm -f -- "$default_splash"

printf '%s\n' "prepare-branding.sh: copied standard live-build bootloader theme"
printf '%s\n' "prepare-branding.sh: installed Chepian splash.png"
printf '%s\n' "prepare-branding.sh: branding preparation completed"
