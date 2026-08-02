#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd -P)"
cd "$repo_root"

required_files=(
  AGENTS.md
  README.md
  LICENSE
  Makefile
  .gitignore
  .gitattributes
  auto/config
  auto/clean
  config/package-lists/chepian-server.list.chroot
  config/includes.chroot/usr/bin/chep
  config/includes.chroot/usr/lib/os-release
  config/includes.chroot/etc/issue
  config/includes.chroot/etc/issue.net
  config/includes.chroot/etc/motd
  config/hooks/live/0100-chepian-config.hook.chroot
  scripts/build.sh
  scripts/clean.sh
  scripts/check.sh
  docs/architecture.md
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    printf '%s\n' "check.sh: missing required file: $file" >&2
    exit 1
  fi
done

shell_files=(
  auto/config
  auto/clean
  config/includes.chroot/usr/bin/chep
  config/hooks/live/0100-chepian-config.hook.chroot
  scripts/build.sh
  scripts/clean.sh
  scripts/check.sh
)

if ! command -v shellcheck >/dev/null 2>&1; then
  printf '%s\n' 'check.sh: shellcheck is required' >&2
  exit 1
fi

shellcheck "${shell_files[@]}"
for file in "${shell_files[@]}"; do
  bash -n "$file"
done

if grep -Il $'\r' "${shell_files[@]}"; then
  printf '%s\n' 'check.sh: CRLF line endings found' >&2
  exit 1
fi

if grep -Ein '^(xorg|xserver-xorg|wayland|gnome|xfce|kde|plasma|task-.*desktop|lightdm|gdm3|sddm|firefox|chromium)([[:space:]]|$)' config/package-lists/chepian-server.list.chroot; then
  printf '%s\n' 'check.sh: graphical package found in package list' >&2
  exit 1
fi

printf '%s\n' 'check.sh: all checks passed'
