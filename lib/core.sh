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

# core::require_version <binary> <min-major> <min-minor>
# Returns 0 if `<binary> --version` reports >= min-major.min-minor, 1 otherwise.
# Parses the first "<digits>.<digits>" substring on the first output line.
core::require_version() {
  local bin="${1}" min_major="${2}" min_minor="${3}"
  local version major minor
  version="$("${bin}" --version 2>/dev/null | head -1 |
    grep -oE '[0-9]+\.[0-9]+' || true)"
  [[ -z "${version}" ]] && return 1
  major="${version%.*}"
  minor="${version#*.}"
  # Force base-10: a version component like "08" or "09" would otherwise be
  # parsed as octal by the arithmetic context and abort with "value too
  # great for base" under set -euo pipefail.
  ((10#${major} > 10#${min_major})) && return 0
  ((10#${major} == 10#${min_major})) && ((10#${minor} >= 10#${min_minor})) && return 0
  return 1
}

# core::backup <absolute-path>
# Moves a file/dir to ~/.dotfiles-backup/YYYYMMDD-HHMMSS/ preserving
# relative path from HOME.
core::backup() {
  local target="${1}"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local relative="${target#"${HOME}/"}"
  local backup_path="${HOME}/.dotfiles-backup/${timestamp}/${relative}"

  mkdir -p "$(dirname "${backup_path}")"
  mv "${target}" "${backup_path}"
  core::log INFO "Backed up: ${target} → ${backup_path}"
}

# core::symlink <repo-relative-src> <absolute-target>
# Creates symlink target → DOTFILES_ROOT/src. On conflict (target exists as a
# real file, directory, or foreign symlink), prompts the user:
#   [b] backup to ~/.dotfiles-backup/ and replace
#   [s] skip (existing file preserved)
#   [q] quit installer
# Idempotent: correct symlink already in place → no-op.
core::symlink() {
  : "${DOTFILES_ROOT:?DOTFILES_ROOT must be exported (normally done by install.sh)}"
  local src="${1}"
  local target="${2}"
  local abs_src="${DOTFILES_ROOT}/${src}"

  # Already correctly linked — no-op
  if [[ -L "${target}" ]] && [[ "$(readlink "${target}")" == "${abs_src}" ]]; then
    core::log INFO "Already linked: ${target}"
    return 0
  fi

  # Target absent — create parent, link, done
  if [[ ! -e "${target}" ]] && [[ ! -L "${target}" ]]; then
    mkdir -p "$(dirname "${target}")"
    ln -sf "${abs_src}" "${target}"
    core::log INFO "Linked: ${target} → ${abs_src}"
    return
  fi

  # Conflict — interactive resolution
  core::log WARN "Conflict: ${target} exists (not managed by dotfiles)"
  printf '  [b] backup to ~/.dotfiles-backup/<ts>/ and replace\n' >&2
  printf '  [s] skip this symlink (existing file preserved)\n' >&2
  printf '  [q] quit installer\n' >&2

  local choice
  while :; do
    printf 'Choice: ' >&2
    read -r choice || {
      core::log ERROR "Cannot read from stdin (not a tty?) — conflict requires interactive resolution"
      return 2
    }
    case "${choice}" in
    b | s | q) break ;;
    *) core::log WARN "Invalid choice: ${choice}. Enter b, s, or q." ;;
    esac
  done

  case "${choice}" in
  b)
    core::backup "${target}" || return 1
    mkdir -p "$(dirname "${target}")"
    ln -sf "${abs_src}" "${target}"
    core::log INFO "Linked: ${target} → ${abs_src}"
    ;;
  s)
    core::log WARN "Skipped: ${target} — your file is unchanged, module may be incomplete"
    ;;
  q)
    core::log ERROR "Aborted by user"
    return 3
    ;;
  esac
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

  [[ -f "${file}" ]] || : >"${file}"

  # Remove existing block (no-op if absent) then append fresh.
  core::remove_block "${file}" "${id}"

  if [[ -s "${file}" ]]; then printf '\n' >>"${file}"; fi
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
