#!/usr/bin/env bash
# uninstall.sh — removes dotfile symlinks and runs each module's uninstall() hook.
# Usage: ./uninstall.sh
set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
export DOTFILES_ROOT

# shellcheck source=lib/modules.sh
source "${DOTFILES_ROOT}/lib/modules.sh"

# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"

# uninstall::run_module <name>
# Sources modules/<name>.sh, removes LINKS symlinks, then runs uninstall().
uninstall::run_module() {
  local name="${1}"
  local module_file="${DOTFILES_ROOT}/modules/${name}.sh"

  install() { :; }
  uninstall() { :; }
  unset MODULE_NAME MODULE_DESC MODULE_PLATFORM LINKS

  # shellcheck source=/dev/null
  source "${module_file}"

  : "${MODULE_NAME:?missing MODULE_NAME in ${module_file}}"
  : "${MODULE_DESC:?missing MODULE_DESC in ${module_file}}"
  : "${MODULE_PLATFORM:?missing MODULE_PLATFORM in ${module_file}}"
  if [[ "${MODULE_NAME}" != "${name}" ]]; then
    core::log ERROR "MODULE_NAME=${MODULE_NAME} does not match filename ${name}.sh"
    return 1
  fi

  if [[ "${MODULE_PLATFORM}" != "all" ]] &&
    [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    core::log INFO "Skipping ${name} (platform: ${MODULE_PLATFORM})"
    return 0
  fi

  core::log INFO "▶ Uninstalling ${name}"

  # 1. Remove LINKS symlinks first (relinquish ownership)
  local link_entry target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    target="${link_entry##*:}"
    if [[ -L "${target}" ]]; then
      rm "${target}"
      core::log INFO "Removed symlink: ${target}"
    elif [[ -e "${target}" ]]; then
      core::log WARN "Not a symlink — skipping: ${target}"
    fi
  done

  # 2. Run uninstall() to clean up external side effects (clones, etc.)
  uninstall

  core::log INFO "✓ ${name}"
}

main() {
  # detect.sh no longer auto-runs on source — invoke detection explicitly.
  # Only detect::os is needed: uninstall::run_module uses DOTFILES_OS for
  # the MODULE_PLATFORM gate, but no code path here reads DOTFILES_PKG_MANAGER.
  # Skipping detect::pkg_manager also lets `./uninstall.sh` succeed on a
  # machine whose pm is broken or uninstalled — removing our symlinks
  # shouldn't require a working package manager.
  detect::os

  local name
  for name in "${DOTFILES_MODULES[@]}"; do
    uninstall::run_module "${name}"
  done
  core::log INFO "Uninstall complete."
}

main "$@"
