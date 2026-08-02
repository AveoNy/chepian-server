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

if [[ -L "$repo_root/config" ]]; then
  printf '%s\n' "prepare-branding.sh: refusing configuration directory symlink: $repo_root/config" >&2
  exit 1
fi
mkdir -p -- "$output_root"

text_files() {
  find "$1" -type f \( -name '*.cfg' -o -name '*.cfg.in' -o -name '*.txt' \) -print0
}

materialize_bootloader_theme() {
  local theme_name="$1"
  local source target expected_source actual_target canonical_root canonical_target

  case "$theme_name" in
    isolinux|syslinux_common) ;;
    *)
      printf '%s\n' "prepare-branding.sh: unsupported bootloader theme: $theme_name" >&2
      return 1
      ;;
  esac

  source="$template_root/$theme_name"
  target="$output_root/$theme_name"

  if [[ ! -d "$source" ]]; then
    printf '%s\n' "prepare-branding.sh: missing live-build bootloader directory: $source" >&2
    return 1
  fi

  expected_source="$(readlink -f -- "$source")"
  canonical_root="$(realpath -e -- "$output_root")"
  case "$canonical_root" in
    "$repo_root"/config/bootloaders) ;;
    *)
      printf '%s\n' "prepare-branding.sh: refusing unsafe bootloader root: $canonical_root" >&2
      return 1
      ;;
  esac

  if [[ -L "$target" ]]; then
    actual_target="$(readlink -f -- "$target")"
    if [[ "$actual_target" != "$expected_source" ]]; then
      printf '%s\n' 'prepare-branding.sh: refusing unexpected bootloader symlink:' >&2
      printf '%s\n' "  source: $expected_source" >&2
      printf '%s\n' "  target: $target" >&2
      printf '%s\n' "  destination: $actual_target" >&2
      return 1
    fi
    unlink -- "$target"
    mkdir -p -- "$target"
  elif [[ -e "$target" ]]; then
    if [[ ! -d "$target" ]]; then
      printf '%s\n' "prepare-branding.sh: target is not a directory: $target" >&2
      return 1
    fi
    if [[ -L "$repo_root/config" || -L "$output_root" ]]; then
      printf '%s\n' "prepare-branding.sh: refusing symbolic-link path component for: $target" >&2
      return 1
    fi
    canonical_target="$(realpath -e -- "$target")"
    if [[ "$canonical_target" != "$canonical_root/$theme_name" ]]; then
      printf '%s\n' "prepare-branding.sh: refusing unsafe local target: $canonical_target" >&2
      return 1
    fi
  else
    mkdir -p -- "$target"
  fi

  cp -a -- "$source/." "$target/"

  if [[ ! -d "$target" || -L "$target" ]]; then
    printf '%s\n' "prepare-branding.sh: failed to materialize local theme: $target" >&2
    return 1
  fi
  canonical_target="$(realpath -e -- "$target")"
  if [[ "$canonical_target" != "$canonical_root/$theme_name" ]]; then
    printf '%s\n' "prepare-branding.sh: materialized target escaped repository: $canonical_target" >&2
    return 1
  fi
  if [[ ! -d "$expected_source" ]]; then
    printf '%s\n' "prepare-branding.sh: source changed unexpectedly: $expected_source" >&2
    return 1
  fi

  case "$theme_name" in
    isolinux)
      if ! find "$target" -maxdepth 1 -type f \( -name 'isolinux.bin' -o -name '*.c32' \) -print -quit | grep -q .; then
        printf '%s\n' "prepare-branding.sh: isolinux template has no bootloader files: $target" >&2
        return 1
      fi
      ;;
    syslinux_common)
      if ! find "$target" -maxdepth 1 -type f \( -name 'live.cfg.in' -o -name '*.cfg' \) -print -quit | grep -q .; then
        printf '%s\n' "prepare-branding.sh: syslinux_common template has no menu configuration: $target" >&2
        return 1
      fi
      ;;
  esac

  printf '%s\n' "prepare-branding.sh: materialized $theme_name from live-build template"
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

materialize_bootloader_theme isolinux
printf '%s\n' 'prepare-branding.sh: prepared isolinux bootloader files'
materialize_bootloader_theme syslinux_common

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
