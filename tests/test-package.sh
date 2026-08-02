#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)"
chep="$repo_root/config/includes.chroot/usr/bin/chep"
lib="$repo_root/config/includes.chroot/usr/lib/chep"
tempdir="$(mktemp -d)"
cleanup() { rm -rf -- "$tempdir"; }
trap cleanup EXIT

cat > "$tempdir/apt-cache" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$CHEP_TEST_LOG"
EOF
cat > "$tempdir/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CHEP_TEST_SUDO_LOG"
EOF
chmod +x "$tempdir/apt-cache"
chmod +x "$tempdir/sudo"
export CHEP_TEST_LOG="$tempdir/apt-cache.log"
export CHEP_TEST_SUDO_LOG="$tempdir/sudo.log"

PATH="$tempdir:$PATH" CHEP_LIB_DIR="$lib" bash "$chep" search nginx
grep -Fx 'search nginx' "$CHEP_TEST_LOG" >/dev/null
[[ ! -e "$CHEP_TEST_SUDO_LOG" ]]
if [[ -e "$tempdir/apt-get.log" ]]; then
  exit 1
fi

if (( EUID != 0 )); then
  PATH="$tempdir:$PATH" bash -c 'source "$1"; CHEP_PROGRAM="$2"; chep_escalate "$CHEP_PROGRAM" install "$3"' bash "$lib/common.sh" "$chep" 'package with spaces'
  mapfile -t sudo_arguments < "$CHEP_TEST_SUDO_LOG"
  [[ "${sudo_arguments[0]}" == -- ]]
  [[ "${sudo_arguments[1]}" == "$chep" ]]
  [[ "${sudo_arguments[2]}" == install ]]
  [[ "${sudo_arguments[3]}" == 'package with spaces' ]]
fi

printf '%s\n' 'test-package.sh: passed'
