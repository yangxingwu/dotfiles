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
  # Detect OS first — bootstrap steps and the module loop both dispatch by it.
  detect::os

  # Stage A: ensure zsh + shell skeleton files exist.
  bootstrap::zsh

  # Stage B: ensure a package manager exists (macOS only).
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    bootstrap::xcode_clt
    bootstrap::homebrew
  fi

  # Stage C: identify the package manager now that one is guaranteed present.
  detect::pkg_manager

  # Stage D: install dev tools every module assumes exist.
  bootstrap::dev_tools

  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  core::summary "---"

  local total=${#DOTFILES_MODULES[@]} i=0 name
  for name in "${DOTFILES_MODULES[@]}"; do
    i=$((i + 1))
    core::run_module install "${name}" "${i}" "${total}"
  done

  core::print_summary
  core::log INFO "Install complete."
}

main "$@"
