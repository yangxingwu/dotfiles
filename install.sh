#!/usr/bin/env bash
# install.sh — dotfiles orchestrator
# Usage: ./install.sh
#
# Installs every module in ${DOTFILES_MODULES} for the current platform. Idempotent.
set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT

# shellcheck source=lib/modules.sh
source "${DOTFILES_ROOT}/lib/modules.sh"
# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"
# shellcheck source=lib/bootstrap.sh
source "${DOTFILES_ROOT}/lib/bootstrap.sh"

main() {
  detect::os

  bootstrap::zsh
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    bootstrap::xcode_clt
    bootstrap::homebrew
  fi
  detect::pkg_manager
  bootstrap::dev_tools

  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  local total=${#DOTFILES_MODULES[@]} i=0 name
  for name in "${DOTFILES_MODULES[@]}"; do
    i=$((i + 1))
    core::run_module install "${name}" "${i}" "${total}"
  done

  core::log INFO "Install complete."
}

main "$@"
