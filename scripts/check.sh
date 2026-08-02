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
  config/includes.chroot/usr/lib/chep/common.sh
  config/includes.chroot/usr/lib/chep/package.sh
  config/includes.chroot/usr/lib/chep/doctor.sh
  config/includes.chroot/usr/lib/os-release
  config/includes.chroot/etc/issue
  config/includes.chroot/etc/issue.net
  config/includes.chroot/etc/motd
  config/hooks/live/0100-chepian-config.hook.chroot
  assets/chepian-apple.svg
  assets/chepian-splash.png
  scripts/build.sh
  scripts/clean.sh
  scripts/check.sh
  scripts/prepare-branding.sh
  tests/test-chep.sh
  tests/test-package.sh
  tests/test-doctor.sh
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
  config/includes.chroot/usr/lib/chep/common.sh
  config/includes.chroot/usr/lib/chep/package.sh
  config/includes.chroot/usr/lib/chep/doctor.sh
  config/hooks/live/0100-chepian-config.hook.chroot
  scripts/build.sh
  scripts/clean.sh
  scripts/check.sh
  scripts/prepare-branding.sh
  tests/test-chep.sh
  tests/test-package.sh
  tests/test-doctor.sh
)

if ! command -v shellcheck >/dev/null 2>&1; then
  printf '%s\n' 'check.sh: shellcheck is required' >&2
  exit 1
fi

shellcheck -x "${shell_files[@]}"
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

if git check-ignore -q assets/chepian-splash.png; then
  printf '%s\n' 'check.sh: ready splash PNG must not be ignored' >&2
  exit 1
fi

if ! git ls-files --error-unmatch -- assets/chepian-splash.png >/dev/null 2>&1; then
  printf '%s\n' 'check.sh: ready splash PNG must be tracked by Git' >&2
  exit 1
fi

if command -v file >/dev/null 2>&1 && ! file -b assets/chepian-splash.png | grep -Eq '^PNG image data, 640 x 480'; then
  printf '%s\n' 'check.sh: ready splash PNG must be 640x480' >&2
  exit 1
fi

for field in 'ID=chepian' 'ID_LIKE=debian'; do
  if ! grep -qxF "$field" config/includes.chroot/usr/lib/os-release; then
    printf '%s\n' "check.sh: os-release is missing $field" >&2
    exit 1
  fi
done

if ! grep -qF 'systemctl set-default multi-user.target' config/hooks/live/0100-chepian-config.hook.chroot; then
  printf '%s\n' 'check.sh: chroot hook must set multi-user.target as default' >&2
  exit 1
fi

for fallback_path in /lib/systemd/system/multi-user.target /etc/systemd/system/default.target; do
  if ! grep -qF "$fallback_path" config/hooks/live/0100-chepian-config.hook.chroot; then
    printf '%s\n' "check.sh: chroot hook is missing default target fallback: $fallback_path" >&2
    exit 1
  fi
done

common_module=config/includes.chroot/usr/lib/chep/common.sh
package_module=config/includes.chroot/usr/lib/chep/package.sh
dispatcher=config/includes.chroot/usr/bin/chep

for requirement in 'chep_escalate()' 'EUID' 'command -v' 'sudo' 'exec sudo --'; do
  if ! grep -qF -- "$requirement" "$common_module"; then
    printf '%s\n' "check.sh: common.sh is missing privilege escalation requirement: $requirement" >&2
    exit 1
  fi
done

if grep -qF 'eval' "$common_module"; then
  printf '%s\n' 'check.sh: common.sh must not use eval' >&2
  exit 1
fi

if ! grep -qF 'chep_escalate' "$package_module"; then
  printf '%s\n' 'check.sh: package.sh must use chep_escalate for changing operations' >&2
  exit 1
fi

for read_command in "apt-cache \"\$command\"" "dpkg-query -W"; do
  if ! grep -qF -- "$read_command" "$package_module"; then
    printf '%s\n' "check.sh: package.sh read operation is missing: $read_command" >&2
    exit 1
  fi
done

for module in common.sh package.sh; do
  if ! grep -qF "load_module $module" "$dispatcher"; then
    printf '%s\n' "check.sh: dispatcher does not load $module" >&2
    exit 1
  fi
done

if ! grep -qF "if [[ \"\$regenerate\" == true ]]" scripts/prepare-branding.sh; then
  printf '%s\n' 'check.sh: rsvg-convert must be limited to --regenerate mode' >&2
  exit 1
fi

for branding_requirement in \
  'materialize_bootloader_theme isolinux' \
  'materialize_bootloader_theme syslinux_common' \
  'isolinux|syslinux_common' \
  'readlink -f' \
  'actual_target' \
  'expected_source' \
  'unlink --' \
  "cp -a -- \"\$source/.\" \"\$target/\"" \
  'syslinux_common/splash.png' \
  'syslinux_common/splash.svg' \
  "-name '*.cfg.in'" \
  'Start Chepian Server Live' \
  'Install Chepian Server'; do
  if ! grep -qF -- "$branding_requirement" scripts/prepare-branding.sh; then
    printf '%s\n' "check.sh: prepare-branding.sh is missing: $branding_requirement" >&2
    exit 1
  fi
done

if grep -qF 'rm -rf' scripts/prepare-branding.sh; then
  printf '%s\n' 'check.sh: prepare-branding.sh must not use rm -rf' >&2
  exit 1
fi

if grep -R -q --include='*.sh' --include='chep' 'eval' config/includes.chroot/usr/bin/chep config/includes.chroot/usr/lib/chep; then
  printf '%s\n' 'check.sh: chep modules must not use eval' >&2
  exit 1
fi

for executable in config/includes.chroot/usr/bin/chep scripts/prepare-branding.sh tests/test-chep.sh tests/test-package.sh tests/test-doctor.sh; do
  if [[ ! -x "$executable" ]]; then
    printf '%s\n' "check.sh: expected executable file: $executable" >&2
    exit 1
  fi
done

if awk '!/^[[:space:]]*($|#)/ { print $1 }' config/package-lists/chepian-server.list.chroot | \
  grep -Eix 'xorg|xserver-xorg.*|xwayland|weston|cage|sway|wayfire|kwin-wayland|mutter|gnome.*|xfce.*|kde.*|plasma.*|task-.*desktop|lightdm|gdm3|sddm|slim|nodm|lxdm|xdm'; then
  printf '%s\n' 'check.sh: graphical package found in package list' >&2
  exit 1
fi

required_menu_labels=(
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

bash tests/test-chep.sh
bash tests/test-package.sh
bash tests/test-doctor.sh

printf '%s\n' 'check.sh: all checks passed'
