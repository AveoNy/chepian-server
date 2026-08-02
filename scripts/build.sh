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

for dependency in lb od sha256sum; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf '%s\n' "build.sh: required command is missing: $dependency" >&2
    exit 1
  fi
done

bash "$repo_root/scripts/prepare-branding.sh"

png_dimensions() {
  local png_file="$1"
  local -a bytes
  local width height

  read -r -a bytes < <(od -An -tu1 -j 16 -N 8 "$png_file")
  if (( ${#bytes[@]} != 8 )); then
    return 1
  fi

  width=$(( (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3] ))
  height=$(( (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7] ))
  [[ "$width" == 640 && "$height" == 480 ]]
}

for splash in \
  "$repo_root/config/bootloaders/isolinux/splash.png" \
  "$repo_root/config/bootloaders/grub/splash.png"; do
  if [[ ! -f "$splash" ]] || ! png_dimensions "$splash"; then
    printf '%s\n' "build.sh: expected 640x480 splash image is missing or invalid: $splash" >&2
    exit 1
  fi
done

lb clean
lb config
lb build

output_name="chepian-server-0.1.0-amd64.iso"
output_iso="$repo_root/$output_name"
source_iso=""

for candidate in live-image-amd64.hybrid.iso binary-hybrid.iso; do
  candidate_path="$repo_root/$candidate"
  if [[ -f "$candidate_path" ]]; then
    source_iso="$candidate_path"
    break
  fi
done

if [[ -z "$source_iso" ]]; then
  shopt -s nullglob
  fallback_isos=()
  for candidate_path in "$repo_root"/*.iso; do
    if [[ "${candidate_path##*/}" != "$output_name" ]]; then
      fallback_isos+=("$candidate_path")
    fi
  done

  case "${#fallback_isos[@]}" in
    0)
      printf '%s\n' 'build.sh: no ISO was created; top-level files:' >&2
      find "$repo_root" -maxdepth 1 -type f -printf '%f\n' | sort >&2
      exit 1
      ;;
    1)
      source_iso="${fallback_isos[0]}"
      ;;
    *)
      printf '%s\n' 'build.sh: multiple unrecognized ISO files found:' >&2
      printf '%s\n' "${fallback_isos[@]##*/}" >&2
      exit 1
      ;;
  esac
fi

mv -f -- "$source_iso" "$output_iso"
(cd "$repo_root" && sha256sum "$output_name" > "$output_name.sha256")
