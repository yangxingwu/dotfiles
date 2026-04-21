#!/usr/bin/env bash
# install.sh — dotfiles orchestrator
# Usage:
#   ./install.sh                        — install all modules
#   ./install.sh --dry-run              — simulate; no system changes
#   ./install.sh --module <name>        — install one module only
#   ./install.sh --module <name> --dry-run
set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
export DOTFILES_ROOT

DRY_RUN=0
TARGET_MODULE=""

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --module)
      [[ $# -ge 2 ]] \
        || { printf 'error: --module requires an argument\n' >&2; exit 1; }
      TARGET_MODULE="${2}"
      shift 2
      ;;
    *)
      printf 'error: unknown argument: %s\n' "${1}" >&2
      exit 1
      ;;
  esac
done

export DRY_RUN

# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"
# shellcheck source=lib/preflight.sh
source "${DOTFILES_ROOT}/lib/preflight.sh"

if [[ "${DRY_RUN}" == "1" ]]; then
  core::log DRY "Dry-run mode — no changes will be made"
fi

core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

# Run full preflight scan when installing all modules.
# Single-module installs skip preflight (user is targeting a specific module).
if [[ -z "${TARGET_MODULE}" ]]; then
  preflight::scan_all
  preflight::report
fi

# install::run_module <module-file>
# Sources the module, checks platform and skip-list, then installs deps + symlinks.
install::run_module() {
  local module_file="${1}"

  # shellcheck source=/dev/null
  source "${module_file}"

  # Honour --module filter
  if [[ -n "${TARGET_MODULE}" ]] \
      && [[ "${MODULE_NAME}" != "${TARGET_MODULE}" ]]; then
    return 0
  fi

  # Platform guard
  if [[ "${MODULE_PLATFORM}" != "all" ]] \
      && [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    core::log INFO "Skipping ${MODULE_NAME} (platform: ${MODULE_PLATFORM})"
    return 0
  fi

  # Preflight skip list
  if preflight::is_skipped "${MODULE_NAME}"; then
    core::log WARN "Skipping ${MODULE_NAME} (conflict not resolved)"
    return 0
  fi

  core::log INFO "▶ ${MODULE_NAME} — ${MODULE_DESC}"

  # Install platform-specific dependencies
  local -a deps=()
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    [[ ${#DEPS_MAC[@]} -gt 0 ]] && deps=("${DEPS_MAC[@]}")
  else
    [[ ${#DEPS_LINUX[@]} -gt 0 ]] && deps=("${DEPS_LINUX[@]}")
  fi
  for dep in "${deps[@]+"${deps[@]}"}"; do
    core::pkg_install "${dep}"
  done

  pre_install

  local link_entry src target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    src="${link_entry%%:*}"
    target="${link_entry##*:}"
    core::symlink "${src}" "${target}"
  done

  post_install

  core::log INFO "✓ ${MODULE_NAME}"
}

# Iterate all module files in alphabetical order
for _module_file in "${DOTFILES_ROOT}/modules"/*.sh; do
  [[ -f "${_module_file}" ]] || continue
  install::run_module "${_module_file}"
done

core::log INFO "Install complete."
