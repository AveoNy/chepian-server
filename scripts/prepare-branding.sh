#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
source_svg="$repo_root/assets/chepian-apple.svg"
source_png="$repo_root/assets/chepian-splash.png"
template_root="/usr/share/live/build/bootloaders"
output_root="$repo_root/config/bootloaders"
regenerate=false
menu_labels=(
  'Chepian Server 0.1.0'
  'Start Chepian Server Live'
  'Start Chepian Server Live (fail-safe mode)'
  'Install Chepian Server'
  'Install Chepian Server with speech synthesis'
  'Advanced installation options'
  'Utilities'
)

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

replace_menu_labels() {
  local theme="$1"
  local theme_dir="$2"
  local menu_file

  while IFS= read -r -d '' menu_file; do
    sed -i \
      -e 's/Debian GNU\/Linux 13 (trixie)/Chepian Server 0.1.0 amd64/g' \
      -e 's/Debian GNU\/Linux Live (amd64, fail-safe mode)/Start Chepian Server Live (fail-safe mode)/g' \
      -e 's/Debian GNU\/Linux Live (amd64)/Start Chepian Server Live/g' \
      -e 's/Debian GNU\/Linux Live (fail-safe mode)/Start Chepian Server Live (fail-safe mode)/g' \
      -e 's/Debian GNU\/Linux Live/Start Chepian Server Live/g' \
      -e 's/Live system (amd64, fail-safe mode)/Start Chepian Server Live (fail-safe mode)/g' \
      -e 's/Live system (amd64)/Start Chepian Server Live/g' \
      -e 's/Live system (fail-safe mode)/Start Chepian Server Live (fail-safe mode)/g' \
      -e 's/Live system/Start Chepian Server Live/g' \
      -e 's/Graphical install/Install Chepian Server/g' \
      -e 's/Install with speech synthesis/Install Chepian Server with speech synthesis/g' \
      -e 's/menu label \^Install$/menu label ^Install Chepian Server/' \
      -e 's/menuentry "Install"/menuentry "Install Chepian Server"/' \
      -e 's/Advanced options/Advanced installation options/g' \
      "$menu_file"
  done < <(find "$theme_dir" -type f \( -name '*.cfg' -o -name '*.conf' \) -print0)

  if [[ "$theme" == "isolinux" ]]; then
    while IFS= read -r -d '' menu_file; do
      sed -i -E 's|^(menu title ).*|\1Chepian Server 0.1.0 amd64|' "$menu_file"
    done < <(find "$theme_dir" -type f -name 'menu.cfg' -print0)
  fi
}

verify_isolinux_labels() {
  local label

  for label in "${menu_labels[@]}"; do
    if ! grep -Frq -- "$label" "$output_root/isolinux"; then
      printf '%s\n' "prepare-branding.sh: ISOLINUX template did not provide a replaceable label: $label" >&2
      return 1
    fi
  done
}

prepare_theme() {
  local theme="$1"
  local template_dir="$template_root/$theme"
  local target_dir="$output_root/$theme"

  if [[ ! -d "$template_dir" ]]; then
    printf '%s\n' "prepare-branding.sh: $theme has no supported live-build theme directory" >&2
    return 1
  fi

  case "$target_dir" in
    "$repo_root"/config/bootloaders/*) ;;
    *)
      printf '%s\n' "prepare-branding.sh: refusing unsafe output path: $target_dir" >&2
      return 1
      ;;
  esac

  mkdir -p "$target_dir"
  cp -a "$template_dir"/. "$target_dir"/
  rm -f -- "$target_dir/splash.svg"
  cp -- "$source_png" "$target_dir/splash.png"
  replace_menu_labels "$theme" "$target_dir"

  if [[ "$theme" == "grub" ]]; then
    local menu_file
    while IFS= read -r -d '' menu_file; do
      sed -i \
        -e '/^set color_normal=white\/black$/d' \
        -e '/^set color_highlight=black\/light-gray$/d' \
        "$menu_file"
      printf '%s\n' 'set color_normal=white/black' 'set color_highlight=black/light-gray' >> "$menu_file"
    done < <(find "$target_dir" -type f -name 'grub.cfg' -print0)
  fi

  printf '%s\n' "prepare-branding.sh: prepared $theme bootloader theme"
  printf '%s\n' "prepare-branding.sh: wrote $target_dir/splash.png"
}

prepare_theme isolinux
verify_isolinux_labels

if ! prepare_theme grub; then
  printf '%s\n' 'prepare-branding.sh: GRUB/UEFI graphic splash is unavailable; preserving textual branding only.' >&2
fi
