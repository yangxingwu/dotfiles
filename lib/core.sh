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

  # Mirror to log file when active (no colour codes in log).
  if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
    printf '[%s] %s\n' "${level}" "${message}" >>"${DOTFILES_LOG_FILE}"
  fi
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

# core::run_cmd <description> <command> [args...]
# Execute a command with output control based on DOTFILES_VERBOSITY.
# In normal mode: output goes to log file only; on failure, tail 20 lines.
# In verbose mode: output streams to terminal AND log file.
# Always appends to DOTFILES_LOG_FILE. Returns the command's exit code.
core::run_cmd() {
  local description="${1}"
  shift

  local start_time end_time elapsed exit_code=0

  core::log INFO "${description}..."
  printf '\n=== %s ===\n' "${description}" >>"${DOTFILES_LOG_FILE}"

  start_time="$(date +%s)"

  if [[ "${DOTFILES_VERBOSITY}" == "verbose" ]]; then
    "$@" 2>&1 | tee -a "${DOTFILES_LOG_FILE}" || exit_code="${PIPESTATUS[0]}"
  else
    "$@" >>"${DOTFILES_LOG_FILE}" 2>&1 || exit_code=$?
  fi

  end_time="$(date +%s)"
  elapsed="$((end_time - start_time))"

  if [[ "${exit_code}" -eq 0 ]]; then
    core::log INFO "Done: ${description} (${elapsed}s)"
  else
    core::log ERROR "Failed: ${description} (exit ${exit_code}, ${elapsed}s)"
    printf '── last 20 lines ──────────────────────────────────\n' >&2
    tail -20 "${DOTFILES_LOG_FILE}" >&2
    printf '───────────────────────────────────────────────────\n' >&2
    printf 'Full log: %s\n' "${DOTFILES_LOG_FILE}" >&2
    return "${exit_code}"
  fi
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

# ── Argument parsing for install.sh / uninstall.sh ─────────────────────

# core::usage — print usage information.
core::usage() {
  printf 'Usage: %s [options]\n\n' "$(basename "${0}")"
  printf 'Options:\n'
  printf '  --only mod1,mod2   Only process specified modules\n'
  printf '  --skip mod1,mod2   Skip specified modules\n'
  printf '  -v, --verbose      Show full command output (default: summary only)\n'
  printf '  --list, -l         List available modules\n'
  printf '  --help, -h         Show this help\n'
}

# core::parse_args — parse CLI options and apply --only/--skip to
# DOTFILES_SELECTED_MODULES. Exits 0 on --help/--list. Returns 1 on any
# parse error. Side effects on DOTFILES_SELECTED_MODULES happen only after
# the full arg list parses cleanly, so a later bad option never leaves the
# global half-modified.
core::parse_args() {
  local mode="" csv=""

  while (($# > 0)); do
    case "${1}" in
    --help | -h)
      core::usage
      exit 0
      ;;
    --list | -l)
      modules::list_modules
      exit 0
      ;;
    --only | --skip)
      if [[ -n "${mode}" ]]; then
        if [[ "${1#--}" == "${mode}" ]]; then
          printf 'error: %s may only be specified once\n' "${1}" >&2
        else
          printf 'error: --only and --skip are mutually exclusive\n' >&2
        fi
        return 1
      fi
      if (($# < 2)); then
        printf 'error: %s requires a comma-separated module list\n' "${1}" >&2
        return 1
      fi
      mode="${1#--}"
      csv="${2}"
      shift 2
      ;;
    --verbose | -v)
      DOTFILES_VERBOSITY="verbose"
      shift
      ;;
    *)
      printf 'error: unknown option: %s\n' "${1}" >&2
      core::usage >&2
      return 1
      ;;
    esac
  done

  # Apply the filter only after the full arg list parses cleanly.
  if [[ -n "${mode}" ]]; then
    modules::filter "${mode}" "${csv}" || return 1
  fi
}

# core::run_module <action> <name> <index> <total>
# Sources modules/<name>.sh, validates the module interface, skips if the
# platform doesn't match, then calls the given action (install or uninstall).
core::run_module() {
  local action="${1}" name="${2}" index="${3}" total="${4}"
  local module_file="${DOTFILES_ROOT}/modules/${name}.sh"

  # Reset hooks to no-op defaults before sourcing the module file.
  # The module's install()/uninstall() definitions will overwrite these.
  # shellcheck disable=SC2317
  install() { :; }
  # shellcheck disable=SC2317
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

  local start_time end_time elapsed
  start_time="$(date +%s)"

  core::log INFO "▶ [${index}/${total}] ${name} — ${MODULE_DESC}"
  core::summary "  ${name}"

  if "${action}"; then
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    core::log INFO "✓ ${name} (${elapsed}s)"
    _CORE_MODULES_OK=$((_CORE_MODULES_OK + 1))
  else
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    core::log ERROR "✗ ${name} failed (${elapsed}s)"
    _CORE_MODULES_FAILED+=("${name}")
  fi
}

# Summary tracking — populated by bootstrap, core::run_module, and modules.
_CORE_SUMMARY=()

# Module outcome tracking for final summary.
_CORE_MODULES_OK=0
_CORE_MODULES_FAILED=()
_CORE_INSTALL_START=""

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

# core::print_final_summary
# Prints the final install/uninstall result with timing and log path.
core::print_final_summary() {
  local end_time elapsed
  end_time="$(date +%s)"
  elapsed="$((end_time - _CORE_INSTALL_START))"

  printf '\n══════════════════════════════════════════════════\n' >&2
  printf '  dotfiles install complete\n' >&2
  printf '  %d modules installed (%ds)\n' "${_CORE_MODULES_OK}" "${elapsed}" >&2
  if [[ ${#_CORE_MODULES_FAILED[@]} -gt 0 ]]; then
    printf '  %d module(s) failed: %s\n' "${#_CORE_MODULES_FAILED[@]}" "${_CORE_MODULES_FAILED[*]}" >&2
  fi
  if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
    printf '  Log: %s\n' "${DOTFILES_LOG_FILE}" >&2
  fi
  printf '══════════════════════════════════════════════════\n' >&2
}
