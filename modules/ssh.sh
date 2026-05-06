#!/usr/bin/env bash
# modules/ssh.sh — SSH client configuration and key management
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="ssh"
MODULE_DESC="SSH client configuration and key management"
MODULE_PLATFORM="all"

install() {
  :
}

uninstall() {
  :
}
