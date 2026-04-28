#!/usr/bin/env bash
# lib/core.sh — Standard library for all modules and the orchestrator.
# Requires: DOTFILES_ROOT set by install.sh/uninstall.sh, DOTFILES_PKG_MANAGER set by detect.sh.
# Safe to source multiple times (function redefinition is idempotent).
set -euo pipefail
IFS=$'\n\t'

# core::log <level> <message>
# Levels: INFO (stdout), WARN/ERROR (stderr). Colours when output fd is a TTY.
core::log() {
  local level="${1}" message="${2}" fd=1

  case "${level}" in
  INFO) fd=1 ;;
  WARN | ERROR) fd=2 ;;
  esac

  # -t N tests whether fd N is a terminal. Check the fd we actually write to,
  # so colours are emitted only when that specific fd goes to a TTY.
  local color="" reset=""
  if [[ -t "${fd}" ]]; then
    reset=$'\033[0m'
    case "${level}" in
    INFO) color=$'\033[0;32m' ;;
    WARN) color=$'\033[0;33m' ;;
    ERROR) color=$'\033[0;31m' ;;
    esac
  fi

  printf '%s %s\n' "${color}[${level}]${reset}" "${message}" >&"${fd}"
}

# core::check_installed <binary> — returns 0 if on PATH.
core::check_installed() {
  command -v "${1}" >/dev/null 2>&1
}

# core::pkg_install <package> [package ...]
# Installs one or more packages via the detected package manager.
# Each pm's install command is already idempotent (skips installed packages).
core::pkg_install() {
  local package

  for package in "$@"; do
    core::log INFO "Installing: ${package}"
    case "${DOTFILES_PKG_MANAGER}" in
    brew)
      brew install "${package}" || {
        core::log ERROR "brew install failed: ${package}"
        return 1
      }
      ;;
    apt)
      sudo apt-get install -y "${package}" || {
        core::log ERROR "apt-get install failed: ${package}"
        return 1
      }
      ;;
    dnf)
      sudo dnf install -y "${package}" || {
        core::log ERROR "dnf install failed: ${package}"
        return 1
      }
      ;;
    *)
      core::log WARN "Unknown package manager — cannot install: ${package}"
      ;;
    esac
  done
}

# Managed blocks in shell init files are delimited by:
#   # BEGIN dotfiles:<id>
#   <content>
#   # END dotfiles:<id>

# core::ensure_block <file> <id> <content>
# Writes a managed block to <file>. Removes any existing block with the
# same id first, then appends the new one.
core::ensure_block() {
  local file="${1}" id="${2}" content="${3}"
  local begin="# BEGIN dotfiles:${id}"
  local end="# END dotfiles:${id}"

  core::remove_block "${file}" "${id}"

  printf '%s\n%s\n%s\n' "${begin}" "${content}" "${end}" >>"${file}"

  core::log INFO "Wrote block '${id}' to ${file}"
}

# core::remove_block <file> <id>
# Removes the managed block with the given id from <file>.
# No-op if the file or block is absent.
core::remove_block() {
  local file="${1}" id="${2}"
  local begin="# BEGIN dotfiles:${id}"
  local end="# END dotfiles:${id}"

  [[ -f "${file}" ]] || return 0
  grep -qxF "${begin}" "${file}" || return 0

  # Write everything outside BEGIN..END to a temp file, then swap.
  local tmp
  tmp="$(mktemp -- "${file}.XXXXXX")"
  awk -v begin="${begin}" -v end="${end}" '
    $0 == begin { skip=1; next }
    $0 == end   { skip=0; next }
    !skip       { print }
  ' "${file}" >"${tmp}"
  chmod 644 "${tmp}"
  mv "${tmp}" "${file}"

  core::log INFO "Removed block '${id}' from ${file}"
}
