#!/usr/bin/env bash
# uninstall.sh — runs each module's uninstall() hook.
# Usage: ./uninstall.sh
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

  local total=${#DOTFILES_MODULES[@]} i=0 name
  for name in "${DOTFILES_MODULES[@]}"; do
    i=$((i + 1))
    core::run_module uninstall "${name}" "${i}" "${total}"
  done

  core::print_summary
  core::log INFO "Uninstall complete."
}

main "$@"
