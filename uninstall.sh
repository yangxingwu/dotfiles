#!/usr/bin/env bash
# uninstall.sh — runs each module's uninstall() hook.
# Usage: ./uninstall.sh

# Bash version gate. See install.sh for rationale (kept identical so users
# hitting either entry point get the same actionable error).
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

# Verbosity: "normal" (default) suppresses command output; "verbose" passes it through.
DOTFILES_VERBOSITY="normal"
DOTFILES_LOG_FILE="/tmp/dotfiles-uninstall-$(date +%Y%m%d-%H%M%S).log"

# shellcheck source=lib/modules.sh
source "${DOTFILES_ROOT}/lib/modules.sh"
# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"

main() {
  core::parse_args "$@"
  core::init

  # Only detect::os is needed: uninstall hooks clean up config files and
  # clones, not packages — so DOTFILES_PKG_MANAGER is never read.
  detect::os

  # Ensure tools installed by modules (cargo, go, etc.) are on PATH.
  # In a normal interactive shell .zprofile is sourced at login; here we
  # source it explicitly because uninstall.sh may run in a non-login
  # process (e.g. CI, a plain bash invocation) where .zprofile was never
  # loaded.
  # shellcheck source=/dev/null
  [[ -f "${HOME}/.zprofile" ]] && source "${HOME}/.zprofile"

  local total=${#DOTFILES_SELECTED_MODULES[@]} i=0 name
  for name in "${DOTFILES_SELECTED_MODULES[@]}"; do
    i=$((i + 1))
    core::run_module uninstall "${name}" "${i}" "${total}"
  done

  core::summary "---"
  core::summary "  Note: binaries installed by modules (brew/apt/dnf packages,"
  core::summary "  rustup toolchain, Go toolchain, cargo-installed tools,"
  core::summary "  go-installed tools) are left in place. Remove them manually"
  core::summary "  if needed."

  core::summary_file "${HOME}/.zprofile"
  core::summary_file "${HOME}/.zshrc"

  core::print_summary
  core::print_final_summary
}

main "$@"
