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

main() {
  core::init
  core::parse_args "$@"

  detect::os

  case "${DOTFILES_OS}" in
  mac) core::log INFO "Prerequisites: run ./bootstrap-macos.sh on a fresh machine" ;;
  linux) core::log INFO "Prerequisites: run ./bootstrap-linux.sh on a fresh machine" ;;
  esac

  detect::pkg_manager

  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  local total=${#DOTFILES_SELECTED_MODULES[@]} i=0 name
  for name in "${DOTFILES_SELECTED_MODULES[@]}"; do
    i=$((i + 1))
    core::run_module install "${name}" "${i}" "${total}"
  done

  core::print_summary
}

main "$@"
