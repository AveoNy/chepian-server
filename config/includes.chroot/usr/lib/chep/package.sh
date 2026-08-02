#!/usr/bin/env bash

CHEP_PROGRAM="${CHEP_PROGRAM:-chep}"

chep_package_require_arguments() {
  if (( $# == 0 )); then
    chep_error "${CHEP_PACKAGE_COMMAND:-package command} requires at least one argument"
    return 2
  fi
}

chep_package_mutate() {
  local command="$1"
  shift
  chep_escalate "$CHEP_PROGRAM" "$command" "$@"
}

chep_package_command() {
  local command="$1"
  shift
  CHEP_PACKAGE_COMMAND="$command"

  case "$command" in
    update)
      chep_package_mutate "$command"
      apt-get update
      ;;
    install|remove|purge)
      chep_package_require_arguments "$@" || return $?
      chep_package_mutate "$command" "$@"
      apt-get "$command" "$@"
      ;;
    search|show)
      chep_package_require_arguments "$@" || return $?
      apt-cache "$command" "$@"
      ;;
    upgrade|autoremove|clean)
      chep_package_mutate "$command"
      apt-get "$command"
      ;;
    list)
      dpkg-query -W -f="\${binary:Package}\t\${Version}\t\${db:Status-Abbrev}\n"
      ;;
    *)
      chep_error "unsupported package command: $command"
      return 2
      ;;
  esac
}
