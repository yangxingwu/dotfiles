#!/usr/bin/env bash
# install.sh — dotfiles orchestrator
# Usage: ./install.sh
#
# Installs every module in ${_MODULES} for the current platform. Idempotent.
# Conflicts are resolved interactively per symlink inside core::symlink.
set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
export DOTFILES_ROOT

# Explicit install order — dependencies first.
# rust must precede nvim (cargo is required for tree-sitter-cli).
# fzf must precede sheldon (sheldon's fzf-tab plugin requires the fzf binary).
readonly _MODULES=(ghostty git rust fzf sheldon starship nvim tmux)

# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"
# shellcheck source=lib/bootstrap.sh
source "${DOTFILES_ROOT}/lib/bootstrap.sh"

# install::run_module <name> <index> <total>
# Sources modules/<name>.sh, validates interface, runs install() then LINKS.
install::run_module() {
  local name="${1}" index="${2}" total="${3}"
  local module_file="${DOTFILES_ROOT}/modules/${name}.sh"

  # Reset module state to prevent bleed-through between modules.
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

  core::log INFO "▶ [${index}/${total}] ${name} — ${MODULE_DESC}"
  install

  local link_entry src target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    src="${link_entry%%:*}"
    target="${link_entry##*:}"
    core::symlink "${src}" "${target}"
  done

  core::log INFO "✓ ${name}"
}

main() {
  # Detect OS first — bootstrap steps and the module loop both dispatch by it.
  detect::os

  # Stage A: ensure zsh + shell skeleton files exist.
  # Linux apt/dnf install zsh; mac is preinstalled. chsh if default shell
  # isn't zsh. Touch ~/.zshrc ~/.zprofile ~/.zshenv as real empty files.
  bootstrap::zsh

  # Stage B: ensure a package manager exists (macOS only).
  # macOS requires Xcode CLT + Homebrew; Linux's apt/dnf ships with the distro.
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    bootstrap::xcode_clt
    bootstrap::homebrew
  fi

  # Stage C: identify the package manager now that one is guaranteed present.
  detect::pkg_manager

  # Stage D: install dev tools every module assumes exist (compiler toolchain,
  # build systems). Hard-fails on an unsupported pm rather than letting
  # modules limp along.
  bootstrap::dev_tools

  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  local total=${#_MODULES[@]} i=0 name
  for name in "${_MODULES[@]}"; do
    i=$((i + 1))
    install::run_module "${name}" "${i}" "${total}"
  done

  core::log INFO "Install complete."
}

main "$@"
