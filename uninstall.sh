#!/usr/bin/env bash
# uninstall.sh — removes dotfile symlinks created by install.sh
# Usage:
#   ./uninstall.sh                 — remove all module symlinks
#   ./uninstall.sh --dry-run       — simulate removal
#   ./uninstall.sh --module <name> — remove one module only
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

if [[ "${DRY_RUN}" == "1" ]]; then
  core::log DRY "Dry-run mode — no changes will be made"
fi

# uninstall::run_module <module-file>
# Removes symlinks created by the module; skips non-symlinks with a warning.
uninstall::run_module() {
  local module_file="${1}"

  # Clear module state to prevent bleed-through between modules
  unset MODULE_NAME MODULE_DESC MODULE_PLATFORM LINKS
  pre_install() { :; }
  install() { :; }
  post_install() { :; }

  # shellcheck source=/dev/null
  source "${module_file}"

  if [[ -n "${TARGET_MODULE}" ]] \
    && [[ "${MODULE_NAME}" != "${TARGET_MODULE}" ]]; then
    return 0
  fi

  if [[ "${MODULE_PLATFORM}" != "all" ]] \
    && [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    core::log INFO "Skipping ${MODULE_NAME} (platform: ${MODULE_PLATFORM})"
    return 0
  fi

  core::log INFO "▶ Uninstalling ${MODULE_NAME}"

  local link_entry target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    target="${link_entry##*:}"

    if [[ -L "${target}" ]]; then
      if [[ "${DRY_RUN}" == "1" ]]; then
        core::log DRY "Would remove symlink: ${target}"
      else
        rm "${target}"
        core::log INFO "Removed symlink: ${target}"
      fi
    elif [[ -e "${target}" ]]; then
      core::log WARN "Not a symlink — skipping: ${target}"
    else
      core::log INFO "Already absent: ${target}"
    fi
  done

  core::log INFO "✓ ${MODULE_NAME}"
}

_found_modules=0
_target_found=0
for _module_file in "${DOTFILES_ROOT}/modules"/*.sh; do
  [[ -f "${_module_file}" ]] || continue
  _found_modules=$((_found_modules + 1))
  uninstall::run_module "${_module_file}"
  if [[ -n "${TARGET_MODULE}" ]] && [[ "${MODULE_NAME}" == "${TARGET_MODULE}" ]]; then
    _target_found=1
  fi
done

if [[ ${_found_modules} -eq 0 ]]; then
  core::log WARN "No modules found in ${DOTFILES_ROOT}/modules"
fi
if [[ -n "${TARGET_MODULE}" ]] && [[ ${_target_found} -eq 0 ]]; then
  printf 'error: module not found: %s\n' "${TARGET_MODULE}" >&2
  exit 1
fi

core::log INFO "Uninstall complete."
