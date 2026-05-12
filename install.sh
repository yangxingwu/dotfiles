#!/usr/bin/env bash
# install.sh — dotfiles orchestrator
# Usage: ./install.sh [--only mod1,mod2] [--skip mod1,mod2] [--list] [--help]
#
# Installs modules for the current platform. Supports --only/--skip filtering.
# Idempotent.

# Bash version gate. The project uses associative arrays and `[[ -v arr[k] ]]`,
# both of which require bash >= 4.3. macOS ships 3.2 system-wide; users must
# run ./bootstrap-macos.sh first to install a modern bash via Homebrew.
# This block uses only bash 3.2 syntax so it executes cleanly on a stale
# interpreter and produces a clear actionable error. major/minor are compared
# separately — concatenating them (e.g. "${maj}${min}") misbehaves once minor
# reaches double digits (4.10 -> "410" vs threshold 43).
_have_major="${BASH_VERSINFO[0]:-0}"
_have_minor="${BASH_VERSINFO[1]:-0}"
if [ "${_have_major}" -lt 4 ] ||
  { [ "${_have_major}" -eq 4 ] && [ "${_have_minor}" -lt 3 ]; }; then
  echo "error: bash >= 4.3 required (current: ${BASH_VERSION:-unknown})" >&2
  echo "       on macOS: run ./bootstrap-macos.sh first" >&2
  exit 1
fi
unset _have_major _have_minor

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
  core::parse_args "$@"
  core::init

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

  local total=${#DOTFILES_SELECTED_MODULES[@]} i=0 name
  for name in "${DOTFILES_SELECTED_MODULES[@]}"; do
    i=$((i + 1))
    core::run_module install "${name}" "${i}" "${total}"
  done

  core::summary_file "${HOME}/.zprofile"
  core::summary_file "${HOME}/.zshrc"

  core::print_summary
  core::print_final_summary
}

main "$@"
