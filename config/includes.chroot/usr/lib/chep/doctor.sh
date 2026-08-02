#!/usr/bin/env bash

CHEP_DOCTOR_WARN=0
CHEP_DOCTOR_FAIL=0
CHEP_ROOT="${CHEP_ROOT:-}"

doctor_path() { printf '%s%s' "$CHEP_ROOT" "$1"; }
doctor_tty() { [[ -t 1 ]]; }
doctor_emit() {
  local level message color reset
  level="$1"; message="$2"; color=""; reset=""
  if doctor_tty; then
    reset='\033[0m'
    case "$level" in OK) color='\033[32m' ;; WARN) color='\033[33m' ;; FAIL) color='\033[31m' ;; INFO) color='\033[36m' ;; esac
  fi
  printf '%b[%4s]%b %s\n' "$color" "$level" "$reset" "$message"
}
doctor_ok() { doctor_emit OK "$1"; }
doctor_info() { doctor_emit INFO "$1"; }
doctor_warn() { CHEP_DOCTOR_WARN=1; doctor_emit WARN "$1"; }
doctor_fail() { CHEP_DOCTOR_FAIL=1; doctor_emit FAIL "$1"; }
doctor_result() {
  if (( CHEP_DOCTOR_FAIL )); then return 2; fi
  if (( CHEP_DOCTOR_WARN )); then return 1; fi
  return 0
}
doctor_uptime() {
  local value uptime_file seconds hours minutes
  if value="$(LC_ALL=C uptime -p 2>/dev/null)"; then
    :
  else
    uptime_file="$(doctor_path /proc/uptime)"
    seconds="$(awk '{print int($1)}' "$uptime_file" 2>/dev/null || printf 0)"
    hours=$((seconds / 3600)); minutes=$(((seconds % 3600) / 60))
    value="up ${hours} hours, ${minutes} minutes"
  fi
  value="$(printf '%s' "$value" | LC_ALL=C sed $'s/\033\\[[0-9;]*[[:alpha:]]//g' | LC_ALL=C tr -d '\r' | LC_ALL=C tr -cd '[:print:]')"
  if [[ -n "$value" ]]; then doctor_info "uptime: $value"; else doctor_info 'uptime: unavailable'; fi
}

doctor_system() {
  local os_release id version target hostname clock_sync
  os_release="$(doctor_path /etc/os-release)"
  if [[ -r "$os_release" ]]; then
    id="$(sed -n 's/^ID=//p' "$os_release" | tr -d '"' | head -n1)"
    version="$(sed -n 's/^VERSION_ID=//p' "$os_release" | tr -d '"' | head -n1)"
    if [[ "$id" == chepian ]]; then doctor_ok "Chepian ID detected (${version:-unknown})"; else doctor_warn "Chepian ID not detected (${id:-unknown})"; fi
  else
    doctor_warn '/etc/os-release is unavailable'
  fi
  doctor_info "kernel: $(uname -r 2>/dev/null || printf unknown)"
  doctor_info "architecture: $(uname -m 2>/dev/null || printf unknown)"
  doctor_uptime
  hostname="$(hostname 2>/dev/null || printf unavailable)"
  doctor_info "hostname: $hostname"
  if chep_command_exists systemctl; then
    target="$(systemctl get-default 2>/dev/null || true)"
    if [[ -n "$target" ]]; then doctor_info "default target: $target"; else doctor_warn 'systemd default target unavailable'; fi
    if systemctl --failed --no-legend 2>/dev/null | grep -q .; then doctor_warn 'failed systemd units detected'; else doctor_ok 'no failed systemd units reported'; fi
    if systemctl is-active --quiet systemd-timesyncd.service 2>/dev/null; then doctor_ok 'time synchronization service active'; else doctor_warn 'time synchronization service inactive'; fi
    if chep_command_exists timedatectl; then
      clock_sync="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)"
      if [[ "$clock_sync" == yes ]]; then doctor_ok 'clock is synchronized'; else doctor_warn 'clock synchronization not confirmed'; fi
    fi
  else
    doctor_info 'systemctl unavailable'
  fi
}

doctor_cpu() {
  local cpus load
  cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 1)"
  load="$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf unavailable)"
  doctor_info "CPUs: $cpus; load average: $load"
  if [[ "$load" != unavailable ]] && awk -v load="$load" -v cpus="$cpus" 'BEGIN { exit !(load >= cpus * 1.5) }'; then doctor_warn 'current load is high relative to CPU count; confirm it persists before acting'; else doctor_ok 'current load is within a normal advisory range'; fi
}

doctor_memory() {
  local meminfo total available swap_total swap_free percent
  meminfo="$(doctor_path /proc/meminfo)"
  total="$(awk '/^MemTotal:/ {print $2}' "$meminfo" 2>/dev/null || printf 0)"
  available="$(awk '/^MemAvailable:/ {print $2}' "$meminfo" 2>/dev/null || printf 0)"
  swap_total="$(awk '/^SwapTotal:/ {print $2}' "$meminfo" 2>/dev/null || printf 0)"
  swap_free="$(awk '/^SwapFree:/ {print $2}' "$meminfo" 2>/dev/null || printf 0)"
  if (( total == 0 )); then doctor_warn 'memory information unavailable'; return; fi
  percent=$((available * 100 / total))
  doctor_info "memory: $(chep_human_bytes $((total * 1024))) total, $(chep_human_bytes $((available * 1024))) available (${percent}%)"
  if (( percent < 5 )); then doctor_fail 'available memory is below 5%'; elif (( percent < 15 )); then doctor_warn 'available memory is below 15%'; else doctor_ok 'available memory is adequate'; fi
  if (( swap_total == 0 )); then doctor_warn 'no swap configured (recommendation only)'; else doctor_info "swap: $(chep_human_bytes $((swap_free * 1024))) free of $(chep_human_bytes $((swap_total * 1024)))"; fi
}

doctor_disk() {
  local filesystem use inode mount
  while IFS=$'\t' read -r filesystem use mount; do
    [[ "$filesystem" =~ ^(tmpfs|devtmpfs|squashfs|overlay)$ ]] && continue
    if (( use >= 95 )); then doctor_fail "disk $mount: ${use}% blocks"; elif (( use >= 85 )); then doctor_warn "disk $mount: ${use}% blocks"; else doctor_ok "disk $mount: ${use}% blocks"; fi
  done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1 {gsub(/%/, "", $5); print $1 "\t" $5 "\t" $6}')
  while IFS=$'\t' read -r filesystem inode mount; do
    [[ "$filesystem" =~ ^(tmpfs|devtmpfs|squashfs|overlay)$ ]] && continue
    if (( inode >= 95 )); then doctor_fail "inode usage $mount: ${inode}%"; elif (( inode >= 85 )); then doctor_warn "inode usage $mount: ${inode}%"; else doctor_ok "inode usage $mount: ${inode}%"; fi
  done < <(df -Pi -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1 {gsub(/%/, "", $5); print $1 "\t" $5 "\t" $6}')
}

doctor_network() {
  local repo_host
  if ip -o link show up 2>/dev/null | grep -qv ' lo:'; then doctor_ok 'UP network interface detected'; else doctor_warn 'no non-loopback UP interface detected'; fi
  if ip route show default 2>/dev/null | grep -q .; then doctor_ok 'IPv4 default route detected'; else doctor_warn 'no IPv4 default route detected'; fi
  repo_host="$(apt-config dump 2>/dev/null | sed -n 's|.*http[s]*://\([^/" ]*\).*|\1|p' | head -n1)"
  if [[ -n "$repo_host" ]] && timeout 5 getent ahosts "$repo_host" >/dev/null 2>&1; then doctor_ok "DNS resolves $repo_host"; else doctor_warn 'configured Debian repository host could not be resolved'; fi
  if ss -ltn 2>/dev/null | grep -Eq '[:.]22[[:space:]]'; then doctor_ok 'SSH listening port detected'; else doctor_warn 'SSH listening port not detected'; fi
}

doctor_services() {
  local service
  for service in ssh.service cron.service rsyslog.service systemd-timesyncd.service; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then doctor_ok "$service active"; else doctor_warn "$service inactive or unavailable"; fi
  done
  for service in docker.service containerd.service kubelet.service; do
    if systemctl list-unit-files "$service" 2>/dev/null | grep -q "^$service"; then doctor_info "$service installed"; else doctor_info "$service not installed"; fi
  done
}

doctor_security() {
  local shadow sshd_bin sshd_output root_login password_auth summary upgrades shadow_mode
  shadow="$(doctor_path /etc/shadow)"; sshd_bin=""
  if [[ -x /usr/sbin/sshd ]]; then sshd_bin=/usr/sbin/sshd; elif chep_command_exists sshd; then sshd_bin="$(command -v sshd)"; fi
  if [[ -n "$sshd_bin" ]]; then
    if sshd_output="$("$sshd_bin" -T 2>/dev/null)"; then
      root_login="$(sed -n 's/^permitrootlogin //p' <<< "$sshd_output" | head -n1)"
      password_auth="$(sed -n 's/^passwordauthentication //p' <<< "$sshd_output" | head -n1)"
      if [[ "$root_login" == no ]]; then doctor_ok 'SSH root login disabled'; else doctor_warn "SSH PermitRootLogin is ${root_login:-unknown}"; fi
      if [[ "$password_auth" == no ]]; then doctor_ok 'SSH password authentication disabled'; elif [[ "$password_auth" == yes ]]; then doctor_info 'SSH password authentication enabled'; else doctor_info 'SSH password authentication policy unavailable'; fi
    else
      doctor_info 'effective SSH configuration unavailable'
    fi
  else
    doctor_info 'OpenSSH server not installed'
  fi
  if [[ -e "$shadow" ]]; then
    shadow_mode="$(stat -c '%a' "$shadow" 2>/dev/null || printf 999)"
    if [[ "$shadow_mode" -le 640 ]]; then doctor_ok '/etc/shadow permissions restricted'; else doctor_warn '/etc/shadow permissions could not be verified'; fi
  else doctor_warn '/etc/shadow permissions could not be verified'; fi
  if summary="$(apt-get -s upgrade 2>&1)"; then
    upgrades="$(sed -n 's/^\([0-9][0-9]*\) upgraded.*/\1/p' <<< "$summary" | head -n1)"
    if [[ -z "$upgrades" ]]; then doctor_warn 'available package upgrades simulation had no summary'; elif (( upgrades > 0 )); then doctor_info "available package upgrades: $upgrades"; else doctor_ok 'available package upgrades: 0'; fi
  else doctor_warn 'available package upgrades simulation failed'; fi
  if find /etc /usr/local /var -xdev -type f -perm -0002 -print -quit 2>/dev/null | grep -q .; then doctor_warn 'world-writable file found in restricted system paths'; else doctor_ok 'no world-writable file found in restricted system paths'; fi
}

doctor_redact() { sed -E 's/((password|passwd|token|secret|authorization|api_key|apikey)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig'; }
doctor_collect_command() { "$@" 2>&1 | doctor_redact; }
doctor_collect() {
  local temp archive timestamp report
  chep_create_secure_tempdir >/dev/null || return 3
  temp="$CHEP_TEMPDIR"; trap 'chep_cleanup_tempdir' EXIT
  report="$temp/report.txt"
  { chep_doctor system; chep_doctor cpu; chep_doctor memory; chep_doctor disk; chep_doctor network; chep_doctor services; chep_doctor security; } > "$report" 2>&1 || true
  doctor_collect_command cat "$(doctor_path /etc/os-release)" > "$temp/os-release.txt"; doctor_collect_command uname -a > "$temp/uname.txt"; doctor_collect_command uptime > "$temp/uptime.txt"; doctor_collect_command cat "$(doctor_path /proc/meminfo)" > "$temp/memory.txt"; doctor_collect_command df -hP > "$temp/disk.txt"; doctor_collect_command ip -brief address > "$temp/network.txt"; doctor_collect_command ip route > "$temp/routes.txt"; doctor_collect_command ss -ltn > "$temp/listening-ports.txt"; doctor_collect_command systemctl --failed > "$temp/failed-units.txt"; doctor_collect_command dpkg-query -W -f="\${binary:Package}\t\${Version}\n" > "$temp/package-summary.txt"; doctor_collect_command journalctl -p warning..alert -n 500 --no-pager > "$temp/journal-errors.txt"
  timestamp="$(date +%Y%m%d-%H%M%S)"; archive="$(pwd -P)/chep-doctor-$timestamp.tar.gz"
  tar -C "$temp" -czf "$archive" .
  chep_info "doctor archive: $archive"
  trap - EXIT; chep_cleanup_tempdir
}

chep_doctor() {
  local section
  section="${1:-all}"
  case "$section" in
    --help|-h) printf '%s\n' 'Usage: chep doctor [system|cpu|memory|disk|network|services|security|--collect]'; return 0 ;;
    --collect) doctor_collect; return $? ;;
    all) doctor_system; doctor_cpu; doctor_memory; doctor_disk; doctor_network; doctor_services; doctor_security ;;
    system) doctor_system ;; cpu) doctor_cpu ;; memory) doctor_memory ;; disk) doctor_disk ;;
    network) doctor_network ;; services) doctor_services ;; security) doctor_security ;;
    *) chep_error "doctor: unknown check: $section"; return 3 ;;
  esac
  doctor_result
}
