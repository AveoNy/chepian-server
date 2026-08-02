#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
source_svg="$repo_root/assets/chepian-apple.svg"
template_root="/usr/share/live/build/bootloaders"
output_root="$repo_root/config/bootloaders"
menu_labels=(
  'Start Chepian Server Live'
  'Start Chepian Server Live (fail-safe mode)'
  'Install Chepian Server'
  'Install Chepian Server with speech synthesis'
  'Advanced installation options'
  'Utilities'
)

if [[ ! -f "$source_svg" ]]; then
  printf '%s\n' "prepare-branding.sh: missing source SVG: $source_svg" >&2
  exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  printf '%s\n' 'prepare-branding.sh: rsvg-convert is required; install it with: sudo apt install librsvg2-bin' >&2
  exit 1
fi

if [[ ! -d "$template_root" ]]; then
  printf '%s\n' "prepare-branding.sh: live-build bootloader templates not found: $template_root" >&2
  exit 1
fi

replace_menu_labels() {
  local theme_dir="$1"
  local menu_file

  while IFS= read -r -d '' menu_file; do
    sed -i \
      -e 's/Debian GNU\/Linux 13 (trixie)/Chepian Server 0.1.0 amd64/g' \
      -e 's/Debian GNU\/Linux Live (fail-safe mode)/Start Chepian Server Live (fail-safe mode)/g' \
      -e 's/Debian GNU\/Linux Live/Start Chepian Server Live/g' \
      -e 's/Live system (fail-safe mode)/Start Chepian Server Live (fail-safe mode)/g' \
      -e 's/Live system/Start Chepian Server Live/g' \
      -e 's/Graphical install/Install Chepian Server/g' \
      -e 's/Install with speech synthesis/Install Chepian Server with speech synthesis/g' \
      -e 's/menu label \^Install$/menu label ^Install Chepian Server/' \
      -e 's/menuentry "Install"/menuentry "Install Chepian Server"/' \
      -e 's/Advanced options/Advanced installation options/g' \
      "$menu_file"
  done < <(find "$theme_dir" -type f \( -name '*.cfg' -o -name '*.conf' \) -print0)
}

prepare_theme() {
  local theme="$1"
  local template_dir="$template_root/$theme"
  local target_dir="$output_root/$theme"
  local target_png="$target_dir/splash.png"

  if [[ ! -d "$template_dir" ]]; then
    printf '%s\n' "prepare-branding.sh: $theme does not support a custom background theme on this live-build version" >&2
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
  rsvg-convert \
    --width 640 \
    --height 480 \
    --output "$target_png" \
    "$source_svg"
  replace_menu_labels "$target_dir"

  if [[ "$theme" == "grub" ]]; then
    while IFS= read -r -d '' menu_file; do
      sed -i \
        -e '/^set color_normal=white\/black$/d' \
        -e '/^set color_highlight=black\/light-gray$/d' \
        "$menu_file"
      printf '%s\n' 'set color_normal=white/black' 'set color_highlight=black/light-gray' >> "$menu_file"
    done < <(find "$target_dir" -type f -name 'grub.cfg' -print0)
  fi

  printf '%s\n' "prepare-branding.sh: prepared $theme bootloader theme"
  printf '%s\n' "prepare-branding.sh: wrote $target_png"
  printf '%s\n' "prepare-branding.sh: expected labels: ${menu_labels[*]}"
}

prepare_theme isolinux
prepare_theme grub
