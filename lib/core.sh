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
# Skips packages that are already installed (checked via brew list / dpkg -s /
# rpm -q). Writes a per-package summary line automatically. Does NOT support
# dnf group installs (@<group>) — handle those directly where needed.
core::pkg_install() {
  local package

  for package in "$@"; do
    case "${DOTFILES_PKG_MANAGER}" in
    brew)
      if brew list "${package}" >/dev/null 2>&1; then
        core::log INFO "Already installed: ${package}"
        core::summary "    ✓ ${package} already installed"
      else
        core::log INFO "Installing: ${package}"
        brew install "${package}" || {
          core::log ERROR "brew install failed: ${package}"
          return 1
        }
        core::summary "    ✓ ${package} installed via brew"
      fi
      ;;
    apt)
      if dpkg -s "${package}" >/dev/null 2>&1; then
        core::log INFO "Already installed: ${package}"
        core::summary "    ✓ ${package} already installed"
      else
        core::log INFO "Installing: ${package}"
        sudo apt-get install -y "${package}" || {
          core::log ERROR "apt-get install failed: ${package}"
          return 1
        }
        core::summary "    ✓ ${package} installed via apt"
      fi
      ;;
    dnf)
      if rpm -q "${package}" >/dev/null 2>&1; then
        core::log INFO "Already installed: ${package}"
        core::summary "    ✓ ${package} already installed"
      else
        core::log INFO "Installing: ${package}"
        sudo dnf install -y "${package}" || {
          core::log ERROR "dnf install failed: ${package}"
          return 1
        }
        core::summary "    ✓ ${package} installed via dnf"
      fi
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
# same id first, then appends the new one. Adds a blank line separator
# before the block if the file already has content.
core::ensure_block() {
  local file="${1}" id="${2}" content="${3}"
  local begin="# BEGIN dotfiles:${id}"
  local end="# END dotfiles:${id}"

  core::remove_block "${file}" "${id}"

  # Separate from previous content with a blank line.
  if [[ -s "${file}" ]] && [[ -n "$(tail -n 1 "${file}")" ]]; then
    printf '\n' >>"${file}"
  fi

  printf '%s\n%s\n%s\n' "${begin}" "${content}" "${end}" >>"${file}"
  core::log INFO "Wrote block '${id}' to ${file}"
}

# core::remove_block <file> <id>
# Removes the managed block with the given id from <file>.
# Normalizes blank lines: collapses consecutive blanks to one, strips
# leading/trailing blanks. No-op if the file or block is absent.
core::remove_block() {
  local file="${1}" id="${2}"
  local begin="# BEGIN dotfiles:${id}"
  local end="# END dotfiles:${id}"

  [[ -f "${file}" ]] || return 0
  grep -qxF "${begin}" "${file}" || return 0

  # Remove the BEGIN..END block and normalize blank lines.
  #
  # Blank lines use delayed printing: encountered blanks are not printed
  # immediately, just flagged. When the next non-blank line arrives:
  #   - If we already printed content before → emit one blank line (separator)
  #   - If this is the first content → emit nothing (strip leading blanks)
  # Trailing blanks are dropped because no content follows to trigger output.
  # Consecutive blanks collapse to one because only one separator is emitted.
  local tmp
  tmp="$(mktemp -- "${file}.XXXXXX")"
  awk -v begin="${begin}" -v end="${end}" '
    $0 == begin { skip=1; next }              # enter block — start skipping
    $0 == end   { skip=0; next }              # leave block — stop skipping
    skip        { next }                      # inside block — discard
    /^$/        { blank=1; next }             # blank line — flag it, do not print
    blank && printed { print "" }             # emit one blank separator (then fall through)
    { blank=0; printed=1; print }             # print current line content (not a blank)
  ' "${file}" >"${tmp}"
  chmod 644 "${tmp}"
  mv "${tmp}" "${file}"

  core::log INFO "Removed block '${id}' from ${file}"
}

# core::run_module <action> <name> <index> <total>
# Sources modules/<name>.sh, validates the module interface, skips if the
# platform doesn't match, then calls the given action (install or uninstall).
core::run_module() {
  local action="${1}" name="${2}" index="${3}" total="${4}"
  local module_file="${DOTFILES_ROOT}/modules/${name}.sh"

  # Reset hooks to no-op defaults before sourcing the module file.
  # The module's install()/uninstall() definitions will overwrite these.
  # shellcheck disable=SC2329  # invoked indirectly via "${action}" below
  install() { :; }
  # shellcheck disable=SC2329
  uninstall() { :; }
  unset MODULE_NAME MODULE_DESC MODULE_PLATFORM

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
    core::summary "  ${name}"
    core::summary "    — skipped (${MODULE_PLATFORM} only)"
    return 0
  fi

  core::log INFO "▶ [${index}/${total}] ${name} — ${MODULE_DESC}"
  core::summary "  ${name}"
  "${action}"
  core::log INFO "✓ ${name}"
}

# Summary tracking — populated by bootstrap, core::run_module, and modules.
_CORE_SUMMARY=()

# core::summary <entry>
# Appends a line to the summary buffer.
core::summary() {
  _CORE_SUMMARY+=("${1}")
}

# core::summary_file <file>
# Appends the content of <file> to the summary buffer, indented.
# No-op if the file is missing or empty.
core::summary_file() {
  local file="${1}"
  [[ -f "${file}" ]] || return 0
  [[ -s "${file}" ]] || return 0

  core::summary "---"
  core::summary "  ${file}"
  local line
  while IFS= read -r line; do
    core::summary "    ${line}"
  done <"${file}"
}

# core::print_summary
# Prints the accumulated summary between box-drawing borders.
core::print_summary() {
  printf '\n══════════════════════════════════════════════════\n'
  printf '  Summary\n'
  printf '══════════════════════════════════════════════════\n'
  local line
  for line in "${_CORE_SUMMARY[@]}"; do
    if [[ "${line}" == "---" ]]; then
      printf '──────────────────────────────────────────────────\n'
    else
      printf '%s\n' "${line}"
    fi
  done
  printf '══════════════════════════════════════════════════\n'
}
