#!/usr/bin/env bash

CHEP_DOCTOR_WARN=0
CHEP_DOCTOR_FAIL=0
CHEP_ROOT="${CHEP_ROOT:-}"

doctor_path() { printf '%s%s' "$CHEP_ROOT" "$1"; }
doctor_tty() { [[ -t 1 ]]; }
doctor_emit() {
  local level="$1" message="$2" color="" reset=""
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

doctor_system() {
  local os_release="$(doctor_path /etc/os-release)" id version target hostname
  if [[ -r "$os_release" ]]; then
    id="$(sed -n 's/^ID=//p' "$os_release" | tr -d '"' | head -n1)"
    version="$(sed -n 's/^VERSION_ID=//p' "$os_release" | tr -d '"' | head -n1)"
    [[ "$id" == chepian ]] && doctor_ok "Chepian ID detected (${version:-unknown})" || doctor_warn "Chepian ID not detected (${id:-unknown})"
  else doctor_warn '/etc/os-release is unavailable'; fi
  doctor_info "kernel: $(uname -r 2>/dev/null || printf unknown)"
  doctor_info "architecture: $(uname -m 2>/dev/null || printf unknown)"
  doctor_info "uptime: $(uptime -p 2>/dev/null || printf unavailable)"
  hostname="$(hostname 2>/dev/null || printf unavailable)"; doctor_info "hostname: $hostname"
  if chep_command_exists systemctl; then
    target="$(systemctl get-default 2>/dev/null || true)"
    [[ -n "$target" ]] && doctor_info "default target: $target" || doctor_warn 'systemd default target unavailable'
    systemctl --failed --no-legend 2>/dev/null | grep -q . && doctor_warn 'failed systemd units detected' || doctor_ok 'no failed systemd units reported'
    systemctl is-active --quiet systemd-timesyncd.service 2>/dev/null && doctor_ok 'time synchronization service active' || doctor_warn 'time synchronization service inactive'
    if chep_command_exists timedatectl; then
      [[ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)" == yes ]] && doctor_ok 'clock is synchronized' || doctor_warn 'clock synchronization not confirmed'
    fi
  else doctor_info 'systemctl unavailable'; fi
}

doctor_cpu() {
  local cpus load
  cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 1)"
  load="$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf unavailable)"
  doctor_info "CPUs: $cpus; load average: $load"
  if [[ "$load" != unavailable ]] && awk -v load="$load" -v cpus="$cpus" 'BEGIN { exit !(load >= cpus * 1.5) }'; then
    doctor_warn 'current load is high relative to CPU count; confirm it persists before acting'
  else doctor_ok 'current load is within a normal advisory range'; fi
}

doctor_memory() {
  local meminfo="$(doctor_path /proc/meminfo)" total available swap_total swap_free percent
  total="$(awk '/^MemTotal:/ {print $2}' "$meminfo" 2>/dev/null || printf 0)"
  available="$(awk '/^MemAvailable:/ {print $2}' "$meminfo" 2>/dev/null || printf 0)"
  swap_total="$(awk '/^SwapTotal:/ {print $2}' "$meminfo" 2>/dev/null || printf 0)"
  swap_free="$(awk '/^SwapFree:/ {print $2}' "$meminfo" 2>/dev/null || printf 0)"
  if (( total == 0 )); then doctor_warn 'memory information unavailable'; return; fi
  percent=$((available * 100 / total))
  doctor_info "memory: $(chep_human_bytes $((total * 1024))) total, $(chep_human_bytes $((available * 1024))) available (${percent}%)"
  (( percent < 5 )) && doctor_fail 'available memory is below 5%' || (( percent < 15 )) && doctor_warn 'available memory is below 15%' || doctor_ok 'available memory is adequate'
  (( swap_total == 0 )) && doctor_warn 'no swap configured (recommendation only)' || doctor_info "swap: $(chep_human_bytes $((swap_free * 1024))) free of $(chep_human_bytes $((swap_total * 1024)))"
}

doctor_disk() {
  local line filesystem use inode mount
  while IFS=$'\t' read -r filesystem use inode mount; do
    [[ "$filesystem" =~ ^(tmpfs|devtmpfs|squashfs|overlay)$ ]] && continue
    if (( use >= 95 || inode >= 95 )); then doctor_fail "disk $mount: ${use}% blocks, ${inode}% inodes";
    elif (( use >= 85 || inode >= 85 )); then doctor_warn "disk $mount: ${use}% blocks, ${inode}% inodes";
    else doctor_ok "disk $mount: ${use}% blocks, ${inode}% inodes"; fi
  done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1 {gsub(/%/, "", $5); print $1 "\t" $5 "\t" 0 "\t" $6}')
  while IFS=$'\t' read -r filesystem inode mount; do
    [[ "$filesystem" =~ ^(tmpfs|devtmpfs|squashfs|overlay)$ ]] && continue
    if (( inode >= 95 )); then doctor_fail "inode usage $mount: ${inode}%";
    elif (( inode >= 85 )); then doctor_warn "inode usage $mount: ${inode}%";
    else doctor_ok "inode usage $mount: ${inode}%"; fi
  done < <(df -Pi -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1 {gsub(/%/, "", $5); print $1 "\t" $5 "\t" $6}')
}

doctor_network() {
  local repo_host
  ip -o link show up 2>/dev/null | grep -qv ' lo:' && doctor_ok 'UP network interface detected' || doctor_warn 'no non-loopback UP interface detected'
  ip route show default 2>/dev/null | grep -q . && doctor_ok 'IPv4 default route detected' || doctor_warn 'no IPv4 default route detected'
  repo_host="$(apt-config dump 2>/dev/null | sed -n 's|.*http[s]*://\([^/" ]*\).*|\1|p' | head -n1)"
  [[ -n "$repo_host" ]] && timeout 5 getent ahosts "$repo_host" >/dev/null 2>&1 && doctor_ok "DNS resolves $repo_host" || doctor_warn 'configured Debian repository host could not be resolved'
  ss -ltn 2>/dev/null | grep -Eq '[:.]22[[:space:]]' && doctor_ok 'SSH listening port detected' || doctor_warn 'SSH listening port not detected'
  systemctl is-active --quiet ssh.service 2>/dev/null && doctor_ok 'ssh.service active' || doctor_warn 'ssh.service inactive or unavailable'
}

doctor_services() {
  local service
  for service in ssh.service cron.service rsyslog.service systemd-timesyncd.service; do
    systemctl is-active --quiet "$service" 2>/dev/null && doctor_ok "$service active" || doctor_warn "$service inactive or unavailable"
  done
  for service in docker.service containerd.service kubelet.service; do
    systemctl list-unit-files "$service" 2>/dev/null | grep -q "^$service" && doctor_info "$service installed" || doctor_info "$service not installed"
  done
}

doctor_security() {
  local ssh_config shadow
  ssh_config="$(doctor_path /etc/ssh/sshd_config)"; shadow="$(doctor_path /etc/shadow)"
  grep -Eiq '^[[:space:]]*PermitRootLogin[[:space:]]+no' "$ssh_config" 2>/dev/null && doctor_ok 'SSH root login disabled' || doctor_warn 'SSH PermitRootLogin no not found'
  grep -Eiq '^[[:space:]]*PasswordAuthentication[[:space:]]+no' "$ssh_config" 2>/dev/null && doctor_ok 'SSH password authentication disabled' || doctor_info 'SSH password authentication policy not explicitly disabled'
  [[ -e "$shadow" ]] && [[ "$(stat -c '%a' "$shadow" 2>/dev/null || printf 999)" -le 640 ]] && doctor_ok '/etc/shadow permissions restricted' || doctor_warn '/etc/shadow permissions could not be verified'
  apt-get -s upgrade 2>/dev/null | grep -Eqi 'security|upgraded' && doctor_info 'package simulation reports potential updates' || doctor_ok 'no simulated package updates reported'
  find /etc /usr/local /var -xdev -type f -perm -0002 -print -quit 2>/dev/null | grep -q . && doctor_warn 'world-writable file found in restricted system paths' || doctor_ok 'no world-writable file found in restricted system paths'
}

doctor_redact() { sed -E 's/((password|passwd|token|secret|authorization|api_key|apikey)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig'; }
doctor_collect_command() { "$@" 2>&1 | doctor_redact; }
doctor_collect() {
  local temp archive timestamp report
  chep_create_secure_tempdir >/dev/null || return 3
  temp="$CHEP_TEMPDIR"
  trap 'chep_cleanup_tempdir' EXIT
  report="$temp/report.txt"
  { chep_doctor system; chep_doctor cpu; chep_doctor memory; chep_doctor disk; chep_doctor network; chep_doctor services; chep_doctor security; } > "$report" 2>&1 || true
  doctor_collect_command cat "$(doctor_path /etc/os-release)" > "$temp/os-release.txt"
  doctor_collect_command uname -a > "$temp/uname.txt"
  doctor_collect_command uptime > "$temp/uptime.txt"
  doctor_collect_command cat "$(doctor_path /proc/meminfo)" > "$temp/memory.txt"
  doctor_collect_command df -hP > "$temp/disk.txt"
  doctor_collect_command ip -brief address > "$temp/network.txt"
  doctor_collect_command ip route > "$temp/routes.txt"
  doctor_collect_command ss -ltn > "$temp/listening-ports.txt"
  doctor_collect_command systemctl --failed > "$temp/failed-units.txt"
  doctor_collect_command dpkg-query -W -f="\${binary:Package}\t\${Version}\n" > "$temp/package-summary.txt"
  doctor_collect_command journalctl -p warning..alert -n 500 --no-pager > "$temp/journal-errors.txt"
  timestamp="$(date +%Y%m%d-%H%M%S)"; archive="$(pwd -P)/chep-doctor-$timestamp.tar.gz"
  tar -C "$temp" -czf "$archive" .
  chep_info "doctor archive: $archive"
  trap - EXIT; chep_cleanup_tempdir
}

chep_doctor() {
  local section="${1:-all}"
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
