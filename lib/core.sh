#!/usr/bin/env bash
# lib/core.sh — Standard library for all modules and the orchestrator.
# Requires: DOTFILES_ROOT exported, DOTFILES_PKG_MANAGER set by detect.sh.
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

# core::ensure_block <file> <id> <content>
# Idempotently writes a managed block into <file>. A block is delimited by
#   # BEGIN dotfiles:<id>
#   <content>
#   # END dotfiles:<id>
# If the block already exists it is removed first, then re-appended.
# <content> is written verbatim; callers pre-expand any variables they want
# captured at install-time, and escape "$" to keep shell expansions literal.
core::ensure_block() {
  local file="${1}" id="${2}" content="${3}"

  # Remove existing block (no-op if absent) then append fresh.
  core::remove_block "${file}" "${id}"

  {
    printf '%s\n' "# BEGIN dotfiles:${id}"
    printf '%s\n' "${content}"
    printf '%s\n' "# END dotfiles:${id}"
  } >>"${file}"
  core::log INFO "Wrote block '${id}' to ${file}"
}

# core::remove_block <file> <id>
# Removes the named managed block (and its surrounding markers) from <file>.
# No-op if <file> does not exist or the block is absent. Used by module
# uninstall() hooks to clean up shell init blocks.
core::remove_block() {
  local file="${1}" id="${2}"
  local begin="# BEGIN dotfiles:${id}"
  local end="# END dotfiles:${id}"

  [[ -f "${file}" ]] || return 0
  grep -qxF "${begin}" "${file}" || return 0

  local tmp
  tmp="$(mktemp -- "${file}.XXXXXX")"
  awk -v begin="${begin}" -v end="${end}" '
    $0 == begin { in_block=1; next }
    $0 == end   { in_block=0; next }
    !in_block   { print }
  ' "${file}" >"${tmp}"

  mv "${tmp}" "${file}"
  core::log INFO "Removed block '${id}' from ${file}"
}
