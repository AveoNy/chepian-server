#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
source_svg="$repo_root/assets/chepian-apple.svg"
source_png="$repo_root/assets/chepian-splash.png"
template_root="/usr/share/live/build/bootloaders"
output_root="$repo_root/config/bootloaders"
syslinux_theme_dir="$output_root/syslinux_common"
syslinux_splash="$output_root/syslinux_common/splash.png"
syslinux_splash_svg="$output_root/syslinux_common/splash.svg"
regenerate=false

usage() {
  printf '%s\n' 'Usage: prepare-branding.sh [--regenerate]'
}

case "${1:-}" in
  '') ;;
  --regenerate) regenerate=true ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ "$regenerate" == true ]]; then
  if [[ ! -f "$source_svg" ]]; then
    printf '%s\n' "prepare-branding.sh: missing source SVG: $source_svg" >&2
    exit 1
  fi
  if ! command -v rsvg-convert >/dev/null 2>&1; then
    printf '%s\n' 'prepare-branding.sh: rsvg-convert is required for --regenerate; install it with: sudo apt install librsvg2-bin' >&2
    exit 1
  fi
  if [[ ! -w "$(dirname -- "$source_png")" ]]; then
    printf '%s\n' "prepare-branding.sh: cannot regenerate non-writable asset: $source_png" >&2
    exit 1
  fi
  rsvg-convert \
    --width 640 \
    --height 480 \
    --output "$source_png" \
    "$source_svg"
fi

if [[ ! -f "$source_png" ]]; then
  printf '%s\n' "prepare-branding.sh: missing ready splash PNG: $source_png" >&2
  exit 1
fi

if ! command -v file >/dev/null 2>&1; then
  printf '%s\n' 'prepare-branding.sh: file is required to validate the ready splash PNG' >&2
  exit 1
fi

if ! file -b "$source_png" | grep -Eq '^PNG image data, 640 x 480'; then
  printf '%s\n' "prepare-branding.sh: splash PNG must be 640x480: $source_png" >&2
  exit 1
fi

if [[ ! -d "$template_root" ]]; then
  printf '%s\n' "prepare-branding.sh: live-build bootloader templates not found: $template_root" >&2
  exit 1
fi

if [[ -L "$output_root" ]]; then
  printf '%s\n' "prepare-branding.sh: refusing bootloader root symlink: $output_root" >&2
  exit 1
fi

if [[ -d "$output_root" ]]; then
  writable_directory="$output_root"
else
  writable_directory="$repo_root/config"
fi

if [[ ! -w "$writable_directory" ]]; then
  printf '%s\n' 'Target bootloader directory is not writable.' >&2
  printf '%s\n' 'Run the full build with:' >&2
  printf '%s\n' '  sudo ./scripts/build.sh' >&2
  exit 1
fi

text_files() {
  find "$1" -type f \( -name '*.cfg' -o -name '*.cfg.in' -o -name '*.txt' \) -print0
}

prepare_bootloader_files() {
  local bootloader="$1"
  local template_dir="$template_root/$bootloader"
  local target_dir="$output_root/$bootloader"

  if [[ ! -d "$template_dir" ]]; then
    printf '%s\n' "prepare-branding.sh: missing live-build bootloader directory: $template_dir" >&2
    return 1
  fi

  case "$target_dir" in
    "$repo_root"/config/bootloaders/*) ;;
    *)
      printf '%s\n' "prepare-branding.sh: refusing unsafe output path: $target_dir" >&2
      return 1
      ;;
  esac

  if [[ -L "$target_dir" ]]; then
    printf '%s\n' "prepare-branding.sh: refusing bootloader directory symlink: $target_dir" >&2
    return 1
  fi

  if [[ -d "$target_dir" ]] && find "$target_dir" -type l -print -quit | grep -q .; then
    printf '%s\n' "prepare-branding.sh: refusing target containing symbolic links: $target_dir" >&2
    return 1
  fi

  mkdir -p "$target_dir"
  cp -a "$template_dir"/. "$target_dir"/
}

replace_syslinux_labels() {
  local theme_dir="$output_root/syslinux_common"
  local menu_file

  while IFS= read -r -d '' menu_file; do
    # Only menu-label values are changed; kernel and boot command lines remain intact.
    sed -i -E \
      -e '/^[[:space:]]*menu[[:space:]]+label[[:space:]]/ {
            s/Live[[:space:]]+system[[:space:]]*\([^)]*(fail[-[:space:]]*safe|failsafe)[^)]*\)/Start Chepian Server Live (fail-safe mode)/I
            s/Live[[:space:]]+system([[:space:]]*\([^)]*\))?/Start Chepian Server Live/I
            s/Start[[:space:]]+installer[[:space:]]+with[[:space:]]+speech[[:space:]]+synthesis/Install Chepian Server with speech synthesis/I
            s/Start[[:space:]]+installer/Install Chepian Server/I
            s/Advanced[[:space:]]+install(ation)?[[:space:]]+options/Advanced installation options/I
          }
          /^[[:space:]]*menu[[:space:]]+title/ {
            s|^[[:space:]]*menu[[:space:]]+title.*$|menu title Chepian Server 0.1.0|I
          }' \
      "$menu_file"
  done < <(text_files "$theme_dir")
}

diagnose_syslinux_theme() {
  local theme_dir="$output_root/syslinux_common"

  printf '%s\n' 'prepare-branding.sh: syslinux_common text files:' >&2
  find "$theme_dir" -type f \( -name '*.cfg' -o -name '*.cfg.in' -o -name '*.txt' \) -printf '%p\n' >&2
  printf '%s\n' 'prepare-branding.sh: existing menu labels:' >&2
  grep -Erih --include='*.cfg' --include='*.cfg.in' --include='*.txt' '^[[:space:]]*menu[[:space:]]+label' "$theme_dir" >&2 || true
  printf '%s\n' 'prepare-branding.sh: existing menu titles:' >&2
  grep -Erih --include='*.cfg' --include='*.cfg.in' --include='*.txt' '^[[:space:]]*menu[[:space:]]+title' "$theme_dir" >&2 || true
}

verify_syslinux_theme() {
  local theme_dir="$syslinux_theme_dir"
  local splash="$syslinux_splash"
  local text_file
  local -A boot_commands_before
  local boot_commands_after

  while IFS= read -r -d '' text_file; do
    boot_commands_before["$text_file"]="$(grep -E '^[[:space:]]*(linux|initrd|append)[[:space:]]' "$text_file" || true)"
  done < <(text_files "$theme_dir")

  replace_syslinux_labels

  if [[ ! -f "$splash" ]] || [[ -e "$syslinux_splash_svg" || -L "$syslinux_splash_svg" ]] || ! file -b "$splash" | grep -Eq '^PNG image data, 640 x 480'; then
    printf '%s\n' 'prepare-branding.sh: syslinux_common splash.png is missing or is not 640x480' >&2
    diagnose_syslinux_theme
    return 1
  fi

  while IFS= read -r -d '' text_file; do
    boot_commands_after="$(grep -E '^[[:space:]]*(linux|initrd|append)[[:space:]]' "$text_file" || true)"
    if [[ "${boot_commands_before[$text_file]}" != "$boot_commands_after" ]]; then
      printf '%s\n' "prepare-branding.sh: boot commands changed unexpectedly: $text_file" >&2
      diagnose_syslinux_theme
      return 1
    fi
  done < <(text_files "$theme_dir")

  if ! grep -Eriq --include='*.cfg' --include='*.cfg.in' --include='*.txt' '^[[:space:]]*menu[[:space:]]+label.*Start Chepian Server Live' "$theme_dir"; then
    printf '%s\n' 'prepare-branding.sh: syslinux_common contains no Chepian Live menu label' >&2
    diagnose_syslinux_theme
    return 1
  fi

  if ! grep -Eriq --include='*.cfg' --include='*.cfg.in' --include='*.txt' '^[[:space:]]*menu[[:space:]]+label.*Install Chepian Server' "$theme_dir"; then
    printf '%s\n' 'prepare-branding.sh: syslinux_common contains no Chepian installer menu label' >&2
    diagnose_syslinux_theme
    return 1
  fi

  if ! grep -Eriq --include='*.cfg' --include='*.cfg.in' --include='*.txt' '^[[:space:]]*menu[[:space:]]+title' "$theme_dir"; then
    printf '%s\n' 'prepare-branding.sh: warning: syslinux_common has no menu title; the splash contains the product title.' >&2
  fi

  printf '%s\n' "prepare-branding.sh: wrote $splash"
  printf '%s\n' 'prepare-branding.sh: verified Chepian Live menu label'
  printf '%s\n' 'prepare-branding.sh: verified Chepian installer menu label'
}

prepare_bootloader_files isolinux
printf '%s\n' 'prepare-branding.sh: prepared isolinux bootloader files'
prepare_bootloader_files syslinux_common

case "$syslinux_splash_svg" in
  "$repo_root"/config/bootloaders/syslinux_common/splash.svg) ;;
  *)
    printf '%s\n' "prepare-branding.sh: refusing unsafe splash path: $syslinux_splash_svg" >&2
    exit 1
    ;;
esac
rm -f -- "$syslinux_splash_svg"
cp -- "$source_png" "$syslinux_splash"
verify_syslinux_theme
printf '%s\n' 'prepare-branding.sh: prepared syslinux_common theme'
