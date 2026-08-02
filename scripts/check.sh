#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
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
  assets/chepian-apple.svg
  scripts/build.sh
  scripts/clean.sh
  scripts/check.sh
  scripts/prepare-branding.sh
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
  scripts/prepare-branding.sh
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

if ! grep -Fq 'viewBox="0 0 640 480"' assets/chepian-apple.svg; then
  printf '%s\n' 'check.sh: branding SVG must use viewBox 0 0 640 480' >&2
  exit 1
fi

if grep -Ein "(href|xlink:href)=[\"'](https?:)?//|<(script|foreignObject)([[:space:]>])" assets/chepian-apple.svg; then
  printf '%s\n' 'check.sh: branding SVG contains an external asset or embedded script' >&2
  exit 1
fi

for field in 'ID=chepian' 'ID_LIKE=debian'; do
  if ! grep -qxF "$field" config/includes.chroot/usr/lib/os-release; then
    printf '%s\n' "check.sh: os-release is missing $field" >&2
    exit 1
  fi
done

if ! grep -qxF 'systemctl set-default multi-user.target' config/hooks/live/0100-chepian-config.hook.chroot; then
  printf '%s\n' 'check.sh: chroot hook must set multi-user.target as default' >&2
  exit 1
fi

if awk '!/^[[:space:]]*($|#)/ { print $1 }' config/package-lists/chepian-server.list.chroot | \
  grep -Eix 'xorg|xserver-xorg.*|xwayland|weston|cage|sway|wayfire|kwin-wayland|mutter|gnome.*|xfce.*|kde.*|plasma.*|task-.*desktop|lightdm|gdm3|sddm|slim|nodm|lxdm|xdm'; then
  printf '%s\n' 'check.sh: graphical package found in package list' >&2
  exit 1
fi

required_menu_labels=(
  'Chepian Server 0.1.0'
  'amd64'
  'Start Chepian Server Live'
  'Start Chepian Server Live (fail-safe mode)'
  'Install Chepian Server'
  'Install Chepian Server with speech synthesis'
  'Advanced installation options'
  'Utilities'
)

for label in "${required_menu_labels[@]}"; do
  if ! grep -Fq -- "$label" scripts/prepare-branding.sh; then
    printf '%s\n' "check.sh: boot menu label is not described: $label" >&2
    exit 1
  fi
done

printf '%s\n' 'check.sh: all checks passed'
