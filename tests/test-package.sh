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
chmod +x "$tempdir/apt-cache"
export CHEP_TEST_LOG="$tempdir/apt-cache.log"

PATH="$tempdir:$PATH" CHEP_LIB_DIR="$lib" bash "$chep" search nginx
grep -Fx 'search nginx' "$CHEP_TEST_LOG" >/dev/null
if [[ -e "$tempdir/apt-get.log" ]]; then
  exit 1
fi

printf '%s\n' 'test-package.sh: passed'
