#!/usr/bin/env bash
# lib/core.sh — Standard library for all modules and the orchestrator.
# Provides: core::log, core::backup, core::symlink, core::pkg_install,
#           core::check_installed, core::require_version.
# Requires: DOTFILES_ROOT exported, DOTFILES_PKG_MANAGER set by detect.sh.
# Safe to source multiple times — function redefinition and plain variable
# reassignment are idempotent in bash.
set -euo pipefail
IFS=$'\n\t'

# ANSI colour codes (used only when stdout is a terminal)
if [[ -t 1 ]]; then
  _CORE_RESET=$'\033[0m'
  _CORE_GREEN=$'\033[0;32m'
  _CORE_YELLOW=$'\033[0;33m'
  _CORE_RED=$'\033[0;31m'
else
  _CORE_RESET=''
  _CORE_GREEN=''
  _CORE_YELLOW=''
  _CORE_RED=''
fi

# core::log <level> <message>
# Levels: INFO WARN ERROR
# ERROR and WARN are written to stderr so they survive stdout redirection.
core::log() {
  local level="${1}"
  local message="${2}"
  local prefix
  local fd=1

  case "${level}" in
  INFO) prefix="${_CORE_GREEN}[INFO]${_CORE_RESET}" ;;
  WARN)
    prefix="${_CORE_YELLOW}[WARN]${_CORE_RESET}"
    fd=2
    ;;
  ERROR)
    prefix="${_CORE_RED}[ERROR]${_CORE_RESET}"
    fd=2
    ;;
  *) prefix="[${level}]" ;;
  esac

  printf '%s %s\n' "${prefix}" "${message}" >&"${fd}"
}

# core::check_installed <binary>
# Returns 0 if the binary is on PATH, 1 otherwise. Pure detection, no side effects.
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
  ((major > min_major)) && return 0
  ((major == min_major)) && ((minor >= min_minor)) && return 0
  return 1
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

  if ! mkdir -p "$(dirname "${backup_path}")"; then
    core::log ERROR "Failed to create backup directory for: ${target}"
    return 1
  fi
  if ! mv "${target}" "${backup_path}"; then
    core::log ERROR "Failed to backup: ${target}"
    return 1
  fi
  core::log INFO "Backed up: ${target} → ${backup_path}"
}

# core::symlink <repo-relative-src> <absolute-target>
# Creates symlink target → DOTFILES_ROOT/src. On conflict (target exists as a
# real file, directory, or foreign symlink), prompts the user interactively:
#   [b] backup existing target to ~/.dotfiles-backup/<ts>/ and replace
#   [s] skip — do NOT create the symlink; user's file is preserved
#   [q] quit the installer immediately (exit 1)
# Idempotent: if target is already the correct symlink, logs and returns 0.
core::symlink() {
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
    if ! mkdir -p "$(dirname "${target}")"; then
      core::log ERROR "Failed to create parent dirs for: ${target}"
      return 1
    fi
    if ! ln -sf "${abs_src}" "${target}"; then
      core::log ERROR "Failed to create symlink: ${target}"
      return 1
    fi
    core::log INFO "Linked: ${target} → ${abs_src}"
    return 0
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
      exit 1
    }
    case "${choice}" in
    b | s | q) break ;;
    *) core::log WARN "Invalid choice: ${choice}. Enter b, s, or q." ;;
    esac
  done

  case "${choice}" in
  b)
    core::backup "${target}" || return 1
    if ! mkdir -p "$(dirname "${target}")"; then
      core::log ERROR "Failed to create parent dirs for: ${target}"
      return 1
    fi
    if ! ln -sf "${abs_src}" "${target}"; then
      core::log ERROR "Failed to create symlink: ${target}"
      return 1
    fi
    core::log INFO "Linked: ${target} → ${abs_src}"
    ;;
  s)
    core::log WARN "Skipped: ${target} — your file is unchanged, module may be incomplete"
    ;;
  q)
    core::log ERROR "Aborted by user"
    exit 1
    ;;
  esac
}

# core::pkg_install <package> [package ...]
# Installs one or more packages via the detected package manager.
# Skips individual packages that are already installed.
core::pkg_install() {
  local package

  for package in "$@"; do
    case "${DOTFILES_PKG_MANAGER}" in
    brew)
      if brew list --formula "${package}" >/dev/null 2>&1 ||
        brew list --cask "${package}" >/dev/null 2>&1; then
        core::log INFO "Already installed: ${package}"
      else
        brew install "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    apt)
      if dpkg -s "${package}" >/dev/null 2>&1; then
        core::log INFO "Already installed: ${package}"
      else
        sudo apt-get install -y "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    dnf)
      if rpm -q "${package}" >/dev/null 2>&1; then
        core::log INFO "Already installed: ${package}"
      else
        sudo dnf install -y "${package}"
        core::log INFO "Installed: ${package}"
      fi
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
# Behaviour:
# - If <file> does not exist, create it first.
# - If the block is absent, append it (with a leading blank line if the file
#   is non-empty) and log "Added block".
# - If the block exists with identical content, log "unchanged" and leave
#   the file untouched.
# - If the block exists with different content, replace content in-place and
#   log "Updated block".
# <content> is written verbatim; callers pre-expand any variables they want
# captured at install-time, and escape "$" to keep shell expansions literal.
core::ensure_block() {
  local file="${1}" id="${2}" content="${3}"
  local begin="# BEGIN dotfiles:${id}"
  local end="# END dotfiles:${id}"

  [[ -f "${file}" ]] || : >"${file}"

  if ! grep -qxF "${begin}" "${file}"; then
    if [[ -s "${file}" ]]; then printf '\n' >>"${file}"; fi
    {
      printf '%s\n' "${begin}"
      printf '%s\n' "${content}"
      printf '%s\n' "${end}"
    } >>"${file}"
    core::log INFO "Added block '${id}' to ${file}"
    return 0
  fi

  local tmp
  tmp="$(mktemp -- "${file}.XXXXXX")"
  awk -v begin="${begin}" -v end="${end}" -v content="${content}" '
    $0 == begin { in_block=1; print; print content; next }
    $0 == end   { in_block=0; print; next }
    !in_block   { print }
  ' "${file}" >"${tmp}"

  if cmp -s "${file}" "${tmp}"; then
    rm -f "${tmp}"
    core::log INFO "Block '${id}' in ${file} unchanged"
  else
    mv "${tmp}" "${file}"
    core::log INFO "Updated block '${id}' in ${file}"
  fi
}

# core::ensure_block_absent <file> <id>
# Removes the named managed block (and its surrounding markers) from <file>.
# No-op if <file> does not exist or the block is absent. Used by module
# uninstall() hooks to clean up shell init blocks.
core::ensure_block_absent() {
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
