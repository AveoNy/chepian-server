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
