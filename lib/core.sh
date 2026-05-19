#!/usr/bin/env bash
# lib/core.sh — Standard library for all modules and the orchestrator.
# Requires: DOTFILES_ROOT set by install.sh/uninstall.sh, DOTFILES_PKG_MANAGER set by detect.sh.
# Safe to source multiple times (function redefinition is idempotent).
set -euo pipefail
IFS=$'\n\t'

# Shared directory for dotfiles-managed shell scripts (sourced from .zshrc).
# shellcheck disable=SC2034  # used by modules that source this lib
DOTFILES_CONFIG_DIR="${HOME}/.config/dotfiles"

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
  if [[ -n "${_CORE_LOG_FILE:-}" ]]; then
    printf '[%s] %s\n' "${level}" "${message}" >>"${_CORE_LOG_FILE}"
  fi
}

# core::check_installed <binary> — returns 0 if on PATH.
core::check_installed() {
  command -v "${1}" >/dev/null 2>&1
}

# core::version_ge <version> <minimum>
# Returns 0 if version >= minimum. Uses sort -V (version sort).
core::version_ge() {
  [[ "$(printf '%s\n%s' "${1}" "${2}" | sort -V | head -1)" == "${2}" ]]
}

# core::file_mode <file> — returns octal permission string (e.g. "600").
core::file_mode() {
  case "${DOTFILES_OS}" in
  mac) stat -f '%Lp' "${1}" ;;
  linux) stat -c '%a' "${1}" ;;
  esac
}

# core::pkg_install <package> [package ...]
# Installs one or more packages via the detected package manager.
# Each package is installed via core::run_cmd for timing and failure handling.
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
        core::run_cmd "Installing ${package}" brew install "${package}" || return 1
        core::summary "    ✓ ${package} installed via brew"
      fi
      ;;
    apt)
      if dpkg -s "${package}" >/dev/null 2>&1; then
        core::log INFO "Already installed: ${package}"
        core::summary "    ✓ ${package} already installed"
      else
        core::run_cmd "Installing ${package}" sudo apt-get install -y "${package}" || return 1
        core::summary "    ✓ ${package} installed via apt"
      fi
      ;;
    dnf)
      if rpm -q "${package}" >/dev/null 2>&1; then
        core::log INFO "Already installed: ${package}"
        core::summary "    ✓ ${package} already installed"
      else
        core::run_cmd "Installing ${package}" sudo dnf install -y "${package}" || return 1
        core::summary "    ✓ ${package} installed via dnf"
      fi
      ;;
    *)
      core::log WARN "Unknown package manager — cannot install: ${package}"
      ;;
    esac
  done
}

# core::pkg_remove <package> [package ...]
# Removes packages via the detected package manager. No-op if not installed.
core::pkg_remove() {
  local package

  for package in "$@"; do
    case "${DOTFILES_PKG_MANAGER}" in
    brew)
      if brew list "${package}" >/dev/null 2>&1; then
        brew uninstall "${package}" || {
          core::log ERROR "brew uninstall failed: ${package}"
          return 1
        }
        core::log INFO "Removed: ${package}"
      fi
      ;;
    apt)
      if dpkg -s "${package}" >/dev/null 2>&1; then
        sudo apt-get remove -y "${package}" || {
          core::log ERROR "apt-get remove failed: ${package}"
          return 1
        }
        core::log INFO "Removed: ${package}"
      fi
      ;;
    dnf)
      if rpm -q "${package}" >/dev/null 2>&1; then
        sudo dnf remove -y "${package}" || {
          core::log ERROR "dnf remove failed: ${package}"
          return 1
        }
        core::log INFO "Removed: ${package}"
      fi
      ;;
    esac
  done
}

# core::run_cmd <description> <command> [args...]
# Execute a command with output control based on _CORE_VERBOSITY.
# In normal mode: output goes to log file only; on failure, tail 20 lines.
# In verbose mode: output streams to terminal AND log file.
# Always appends to _CORE_LOG_FILE. Returns the command's exit code.
core::run_cmd() {
  local description="${1}"
  shift

  local start_time end_time elapsed exit_code=0

  core::log INFO "${description}..."
  printf '\n=== %s ===\n' "${description}" >>"${_CORE_LOG_FILE}"

  # Record log position after header — on failure, only show this command's output.
  local log_offset
  log_offset=$(wc -l <"${_CORE_LOG_FILE}")

  start_time="$(date +%s)"

  if [[ "${_CORE_VERBOSITY}" == "verbose" ]]; then
    "$@" 2>&1 | tee -a "${_CORE_LOG_FILE}" || exit_code="${PIPESTATUS[0]}"
  else
    "$@" >>"${_CORE_LOG_FILE}" 2>&1 || exit_code=$?
  fi

  end_time="$(date +%s)"
  elapsed="$((end_time - start_time))"

  if [[ "${exit_code}" -eq 0 ]]; then
    if [[ "${elapsed}" -eq 0 ]]; then
      # Fast command: replace the "..." line with a single completion line.
      core::log INFO "✓ ${description}"
    else
      core::log INFO "Done: ${description} (${elapsed}s)"
    fi
  else
    local error_context
    error_context="$(tail -n +"$((log_offset + 1))" "${_CORE_LOG_FILE}" | tail -20)"
    core::log ERROR "Failed: ${description} (exit ${exit_code}, ${elapsed}s)"
    printf '── last 20 lines ──────────────────────────────────\n' >&2
    printf '%s\n' "${error_context}" >&2
    printf '── Full log: %s ───────────────────────────────────\n' "${_CORE_LOG_FILE}" >&2
    return "${exit_code}"
  fi
}

# Managed blocks in shell init files are delimited by:
#   # BEGIN dotfiles:<id>
#   <content>
#   # END dotfiles:<id>

# core::ensure_block <file> <id> <content> [position]
# Writes a managed block to <file>. Removes any existing block with the
# same id first, then inserts the new one. position is "append" (default)
# or "prepend". A blank line separates the block from surrounding content.
core::ensure_block() {
  local file="${1}" id="${2}" content="${3}" position="${4:-append}"
  local begin="# BEGIN dotfiles:${id}"
  local end="# END dotfiles:${id}"

  core::remove_block "${file}" "${id}"

  case "${position}" in
  prepend)
    local tmp
    tmp="$(mktemp -- "${file}.XXXXXX")"
    {
      printf '%s\n%s\n%s\n' "${begin}" "${content}" "${end}"
      if [[ -s "${file}" ]]; then
        printf '\n'
        cat "${file}"
      fi
    } >"${tmp}"
    chmod "$(core::file_mode "${file}")" "${tmp}"
    mv "${tmp}" "${file}"
    ;;
  *)
    # Separate from previous content with a blank line.
    if [[ -s "${file}" ]] && [[ -n "$(tail -n 1 "${file}")" ]]; then
      printf '\n' >>"${file}"
    fi
    printf '%s\n%s\n%s\n' "${begin}" "${content}" "${end}" >>"${file}"
    ;;
  esac

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
  chmod "$(core::file_mode "${file}")" "${tmp}"
  mv "${tmp}" "${file}"

  core::log INFO "Removed block '${id}' from ${file}"
}

# core::backup <path>
# Backs up a file or directory by appending a timestamp suffix.
# Creates: <path>.bak.<YYYYMMDD-HHMMSS>
# No-op if <path> does not exist.
# Logs the backup path so the user knows where to find it for restoration.
#
# Restore example:
#   rm -rf <path>
#   mv <path>.bak.<timestamp> <path>
core::backup() {
  local path="${1}"
  [[ -e "${path}" ]] || return 0

  local backup
  backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
  mv "${path}" "${backup}"
  core::log INFO "Backed up ${path} → ${backup}"
  core::summary "    ✓ backed up → ${backup}"
}

# ── Module status tracking ───────────────────────────────────────────

_CORE_STATUS_FILE="${DOTFILES_CONFIG_DIR}/installed-modules"

# core::module_installed <name>
# Record that a module has been successfully installed.
# Adds or updates the module's entry in the status file with current timestamp.
core::module_installed() {
  local name="${1}"
  local timestamp
  timestamp="$(date +%Y-%m-%dT%H:%M:%S)"

  mkdir -p "$(dirname "${_CORE_STATUS_FILE}")"

  # Remove existing entry (if re-installing), then append new one.
  if [[ -f "${_CORE_STATUS_FILE}" ]]; then
    grep -v "^${name} " "${_CORE_STATUS_FILE}" >"${_CORE_STATUS_FILE}.tmp" || true
    mv "${_CORE_STATUS_FILE}.tmp" "${_CORE_STATUS_FILE}"
  fi
  printf '%s %s\n' "${name}" "${timestamp}" >>"${_CORE_STATUS_FILE}"
}

# core::module_is_installed <name>
# Check whether a module has been previously installed (exists in status file).
# Returns 0 if installed, 1 if not.
core::module_is_installed() {
  local name="${1}"
  [[ -f "${_CORE_STATUS_FILE}" ]] && grep -q "^${name} " "${_CORE_STATUS_FILE}"
}

# core::module_uninstalled <name>
# Remove a module's entry from the status file (called after successful uninstall).
core::module_uninstalled() {
  local name="${1}"
  [[ -f "${_CORE_STATUS_FILE}" ]] || return 0
  grep -v "^${name} " "${_CORE_STATUS_FILE}" >"${_CORE_STATUS_FILE}.tmp" || true
  mv "${_CORE_STATUS_FILE}.tmp" "${_CORE_STATUS_FILE}"
}

# core::show_status — display installed modules from status file.
core::show_status() {
  if [[ ! -f "${_CORE_STATUS_FILE}" ]]; then
    printf 'No modules installed (status file not found).\n'
    return 0
  fi
  printf 'Installed modules:\n'
  local name timestamp
  while IFS=' ' read -r name timestamp; do
    printf '  %-20s %s\n' "${name}" "${timestamp}"
  done <"${_CORE_STATUS_FILE}"
}

# ── Argument parsing for install.sh / uninstall.sh ─────────────────────

# core::usage — print usage information.
core::usage() {
  printf 'Usage: %s [options]\n\n' "$(basename "${0}")"
  printf 'Processes all modules by default. Use --only/--skip to filter.\n\n'
  printf 'Options:\n'
  printf '  --only mod1,mod2   Only process specified modules\n'
  printf '  --skip mod1,mod2   Skip specified modules\n'
  printf '  --mirror-cn        Use China mirrors (USTC, rsproxy.cn, goproxy.cn)\n'
  printf '  -v, --verbose      Show full command output (default: progress only)\n'
  printf '  --summary          Show detailed summary after completion\n'
  printf '  --status           Show installed modules and timestamps\n'
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
    --status)
      core::show_status
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
      _CORE_VERBOSITY="verbose"
      shift
      ;;
    --summary)
      _CORE_SHOW_SUMMARY="true"
      shift
      ;;
    --mirror-cn)
      _CORE_MIRROR_CN="true"
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

# core::init — initialize runtime state (verbosity default, log file, timing).
# Call once from install.sh / uninstall.sh before core::parse_args.
core::init() {
  _CORE_VERBOSITY="normal"
  _CORE_SHOW_SUMMARY="false"
  _CORE_MIRROR_CN="false"
  local script_name
  script_name="$(basename "${0}" .sh)"
  _CORE_LOG_FILE="/tmp/dotfiles-${script_name}-$(date +%Y%m%d-%H%M%S).log"
  _CORE_INSTALL_START="$(date +%s)"
}

# core::run_module <action> <name> <index> <total>
# Sources modules/<name>.sh, validates the module interface, skips if the
# platform doesn't match, then calls the given action (install or uninstall).
core::run_module() {
  local action="${1}" name="${2}" index="${3}" total="${4}"
  local module_file="${DOTFILES_ROOT}/modules/${name}.sh"

  # Reset hooks to no-op defaults before sourcing the module file.
  # The module's install()/uninstall() definitions will overwrite these.
  # shellcheck disable=SC2317,SC2329
  install() { :; }
  # shellcheck disable=SC2317,SC2329
  uninstall() { :; }
  unset MODULE_NAME MODULE_DESC MODULE_PLATFORM MODULE_DEPS

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

  # Check module dependencies (if declared) — only for install action.
  # MODULE_DEPS is an optional array declared by modules that need other modules
  # to be installed first. Unset means "no dependencies".
  if [[ "${action}" == "install" ]] && [[ -n "${MODULE_DEPS+x}" ]]; then
    local -a missing=()
    local dep
    for dep in "${MODULE_DEPS[@]}"; do
      if ! core::module_is_installed "${dep}"; then
        missing+=("${dep}")
      fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
      local missing_list deps_list
      missing_list="$(printf '%s, ' "${missing[@]}")"
      missing_list="${missing_list%, }"
      deps_list="$(printf '%s, ' "${MODULE_DEPS[@]}")"
      deps_list="${deps_list%, }"
      core::log ERROR "${name} requires: ${deps_list} — not installed: ${missing_list}"
      core::summary "  ${name}"
      core::summary "    ✗ skipped (missing deps: ${missing_list})"
      return 0
    fi
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
    # Record module status (install → mark done, uninstall → clear).
    if [[ "${action}" == "install" ]]; then
      core::module_installed "${name}"
    else
      core::module_uninstalled "${name}"
    fi
  else
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    core::log ERROR "✗ ${name} failed (${elapsed}s)"
    return 1
  fi
}

# Summary tracking — populated by bootstrap, core::run_module, and modules.
_CORE_SUMMARY=()

# Module outcome tracking for final summary.
_CORE_MODULES_OK=0
_CORE_INSTALL_START=""

# core::summary <entry>
# Appends a line to the summary buffer.
core::summary() {
  _CORE_SUMMARY+=("${1}")
}

# core::print_summary
# In --summary mode: prints the detailed summary box with all collected
# entries plus timing/log path. In default mode: prints a single INFO line.
core::print_summary() {
  local end_time elapsed
  end_time="$(date +%s)"
  elapsed="$((end_time - _CORE_INSTALL_START))"

  local stats="${_CORE_MODULES_OK} modules (${elapsed}s)"
  if [[ -n "${_CORE_LOG_FILE:-}" ]]; then
    stats="${stats}. Log: ${_CORE_LOG_FILE}"
  fi

  if [[ "${_CORE_SHOW_SUMMARY}" == "true" ]]; then
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
    printf '──────────────────────────────────────────────────\n'
    printf '  %s\n' "${stats}"
    printf '══════════════════════════════════════════════════\n'
  else
    core::log INFO "Install complete: ${stats}"
  fi
}
