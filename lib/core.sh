#!/usr/bin/env bash
# lib/core.sh — Standard library for all modules and the orchestrator.
# Provides: core::log, core::backup, core::symlink, core::pkg_install.
# Requires: DOTFILES_ROOT exported, DOTFILES_PKG_MANAGER set by detect.sh.
# DRY_RUN=1 makes all destructive operations no-ops (logged only).
set -euo pipefail
IFS=$'\n\t'

# ANSI colour codes (used only when stdout is a terminal)
if [[ -t 1 ]]; then
  readonly _CORE_RESET=$'\033[0m'
  readonly _CORE_GREEN=$'\033[0;32m'
  readonly _CORE_YELLOW=$'\033[0;33m'
  readonly _CORE_RED=$'\033[0;31m'
  readonly _CORE_CYAN=$'\033[0;36m'
else
  readonly _CORE_RESET=''
  readonly _CORE_GREEN=''
  readonly _CORE_YELLOW=''
  readonly _CORE_RED=''
  readonly _CORE_CYAN=''
fi

# core::log <level> <message>
# Levels: INFO WARN ERROR DRY
core::log() {
  local level="${1}"
  local message="${2}"
  local prefix

  case "${level}" in
    INFO)  prefix="${_CORE_GREEN}[INFO]${_CORE_RESET}" ;;
    WARN)  prefix="${_CORE_YELLOW}[WARN]${_CORE_RESET}" ;;
    ERROR) prefix="${_CORE_RED}[ERROR]${_CORE_RESET}" ;;
    DRY)   prefix="${_CORE_CYAN}[DRY-RUN]${_CORE_RESET}" ;;
    *)     prefix="[${level}]" ;;
  esac

  printf '%s %s\n' "${prefix}" "${message}"
}

# core::backup <absolute-path>
# Moves an existing file/dir to ~/.dotfiles-backup/YYYYMMDD-HHMMSS/ preserving
# relative path from HOME.
core::backup() {
  local target="${1}"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local backup_dir="${HOME}/.dotfiles-backup/${timestamp}"
  if [[ "${target}" != "${HOME}"/* ]]; then
    core::log ERROR "Backup target must be under HOME: ${target}"
    return 1
  fi
  local relative="${target#"${HOME}/"}"
  local backup_path="${backup_dir}/${relative}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would backup: ${target} → ${backup_path}"
    return 0
  fi

  mkdir -p "$(dirname "${backup_path}")"
  if ! mv "${target}" "${backup_path}"; then
    core::log ERROR "Failed to backup: ${target}"
    return 1
  fi
  core::log INFO "Backed up: ${target} → ${backup_path}"
}

# core::symlink <repo-relative-src> <absolute-target>
# Creates symlink target → DOTFILES_ROOT/src. Idempotent: skips if already correct.
core::symlink() {
  local src="${1}"
  local target="${2}"
  local abs_src="${DOTFILES_ROOT}/${src}"

  # Already correctly linked — skip silently
  if [[ -L "${target}" ]] && [[ "$(readlink "${target}")" == "${abs_src}" ]]; then
    core::log INFO "Already linked: ${target}"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would symlink: ${target} → ${abs_src}"
    return 0
  fi

  if ! mkdir -p "$(dirname "${target}")"; then
    core::log ERROR "Failed to create parent dirs for: ${target}"
    return 1
  fi
  if ! ln -sf "${abs_src}" "${target}"; then
    core::log ERROR "Failed to create symlink: ${target}"
    return 1
  fi
  core::log INFO "Linked: ${target} → ${abs_src}"
}

# core::pkg_install <package-name>
# Installs a package via the detected package manager. Skips if already installed.
core::pkg_install() {
  local package="${1}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would install package: ${package}"
    return 0
  fi

  case "${DOTFILES_PKG_MANAGER}" in
    brew)
      if brew list --formula "${package}" &>/dev/null \
        || brew list --cask "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        brew install "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    apt)
      if dpkg -s "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo apt-get install -y "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    dnf)
      if rpm -q "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo dnf install -y "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    pacman)
      if pacman -Q "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo pacman -S --noconfirm "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    *)
      core::log WARN "Unknown package manager — cannot install: ${package}"
      ;;
  esac
}
