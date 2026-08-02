#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
source_svg="$repo_root/assets/chepian-apple.svg"
source_png="$repo_root/assets/chepian-splash.png"
template_root="/usr/share/live/build/bootloaders"
output_root="$repo_root/config/bootloaders"
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
    # Only menu-label lines are changed; kernel, initrd, append, include, and paths remain intact.
    sed -i -E \
      -e '/^[[:space:]]*(menu[[:space:]]+label|menuentry)[[:space:]]/ {
            s/Live[[:space:]]+system[[:space:]]*\(amd64[[:space:],-]*(fail[-[:space:]]*safe|failsafe)([[:space:]]+mode)?\)/Start Chepian Server Live (fail-safe mode)/I
            s/Live[[:space:]]+system[[:space:]]*\(amd64\)/Start Chepian Server Live/I
            s/Start[[:space:]]+installer[[:space:]]+with[[:space:]]+speech[[:space:]]+synthesis/Install Chepian Server with speech synthesis/I
            s/Start[[:space:]]+installer/Install Chepian Server/I
            s/Advanced[[:space:]]+install(ation)?[[:space:]]+options/Advanced installation options/I
          }' \
      "$menu_file"
  done < <(find "$theme_dir" -type f \( -name '*.cfg' -o -name '*.txt' \) -print0)

  # Utilities is already the required label and is intentionally left unchanged.

  if [[ "$theme" == "isolinux" ]]; then
    while IFS= read -r -d '' menu_file; do
      sed -i -E 's|^[[:space:]]*menu[[:space:]]+title.*$|menu title Chepian Server 0.1.0|I' "$menu_file"
    done < <(find "$theme_dir" -type f \( -name '*.cfg' -o -name '*.txt' \) -print0)
  fi
}

verify_isolinux_labels() {
  local theme_dir="$output_root/isolinux"
  local splash="$theme_dir/splash.png"

  if [[ ! -f "$splash" ]] || ! file -b "$splash" | grep -Eq '^PNG image data, 640 x 480'; then
    printf '%s\n' 'prepare-branding.sh: ISOLINUX splash.png is missing or is not 640x480' >&2
    return 1
  fi

  if ! grep -Eriq --include='*.cfg' --include='*.txt' '(^|[[:space:]])(menu[[:space:]]+label|menuentry).*Start Chepian Server Live' "$theme_dir"; then
    printf '%s\n' 'prepare-branding.sh: ISOLINUX theme contains no Chepian Live menu label' >&2
    return 1
  fi

  if ! grep -Eriq --include='*.cfg' --include='*.txt' '(^|[[:space:]])(menu[[:space:]]+label|menuentry).*Install Chepian Server' "$theme_dir"; then
    printf '%s\n' 'prepare-branding.sh: ISOLINUX theme contains no Chepian installer menu label' >&2
    return 1
  fi

  if ! grep -Eriq --include='*.cfg' --include='*.txt' '^[[:space:]]*menu[[:space:]]+title' "$theme_dir"; then
    printf '%s\n' 'prepare-branding.sh: warning: ISOLINUX template has no menu title; the splash contains the product title.' >&2
  fi
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
