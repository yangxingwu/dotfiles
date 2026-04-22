#!/usr/bin/env bash
# install.sh — dotfiles orchestrator
# Usage:
#   ./install.sh                        — install all modules
#   ./install.sh --dry-run              — simulate; no system changes
#   ./install.sh --module <name>        — install one module only (<name>.sh)
#   ./install.sh -h | --help            — show usage and exit
#
# Convention: the file modules/<name>.sh must declare MODULE_NAME="<name>".
# --module matches on the filename, so there is no mismatch to worry about.
set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
export DOTFILES_ROOT

# Explicit install order — dependencies first.
# rust must precede nvim (cargo is required for tree-sitter-cli).
readonly _MODULE_ORDER=(ghostty git rust nvim tmux zsh)

# Set > 0 once the first module's install() runs — lets the interrupt handler
# distinguish "aborted before any changes" from "aborted mid-install."
_MODULES_STARTED=0

install::usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS]

Options:
  --dry-run              Simulate the install; make no system changes.
  --module <name>        Install only modules/<name>.sh.
  -h, --help             Show this help and exit.
EOF
}

# install::parse_args <argv...>
# Sets DRY_RUN and TARGET_MODULE globals. Rejects duplicate --module and
# unknown flags. Returns 2 on --help so main() can exit cleanly.
install::parse_args() {
  DRY_RUN=0
  TARGET_MODULE=""

  while [[ $# -gt 0 ]]; do
    case "${1}" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --module)
      if [[ $# -lt 2 ]]; then
        printf 'error: --module requires an argument\n' >&2
        return 1
      fi
      if [[ -n "${TARGET_MODULE}" ]]; then
        printf 'error: --module given more than once\n' >&2
        return 1
      fi
      TARGET_MODULE="${2}"
      shift 2
      ;;
    -h | --help)
      install::usage
      return 2
      ;;
    *)
      printf 'error: unknown argument: %s\n' "${1}" >&2
      install::usage >&2
      return 1
      ;;
    esac
  done
}

# install::run_module <module-name> <index> <total>
# Sources modules/<name>.sh and runs its lifecycle. Wrong-platform and
# unresolved-conflict modules are logged and skipped (not errors).
install::run_module() {
  local name="${1}" index="${2}" total="${3}"
  local module_file="${DOTFILES_ROOT}/modules/${name}.sh"

  # Prevent leftover hooks/vars from a prior module leaking into this one.
  pre_install() { :; }
  install() { :; }
  post_install() { :; }
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
  if preflight::is_skipped "${name}"; then
    core::log WARN "Skipping ${name} (conflict not resolved)"
    return 0
  fi

  core::log INFO "▶ [${index}/${total}] ${name} — ${MODULE_DESC}"
  pre_install
  _MODULES_STARTED=$((_MODULES_STARTED + 1))
  install

  local link_entry src target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    src="${link_entry%%:*}"
    target="${link_entry##*:}"
    core::symlink "${src}" "${target}"
  done

  post_install
  core::log INFO "✓ ${name}"
}

# install::on_interrupt — trap handler for Ctrl-C / SIGTERM.
install::on_interrupt() {
  if [[ "${_MODULES_STARTED}" -gt 0 ]]; then
    core::log ERROR "Interrupted mid-install — some modules may be partially applied"
  else
    core::log ERROR "Interrupted before any modules ran"
  fi
  exit 130
}

main() {
  local rc=0
  install::parse_args "$@" || rc=$?
  if [[ "${rc}" -eq 2 ]]; then
    exit 0
  elif [[ "${rc}" -ne 0 ]]; then
    exit "${rc}"
  fi
  export DRY_RUN

  # shellcheck source=lib/detect.sh
  source "${DOTFILES_ROOT}/lib/detect.sh"
  # shellcheck source=lib/core.sh
  source "${DOTFILES_ROOT}/lib/core.sh"
  # shellcheck source=lib/preflight.sh
  source "${DOTFILES_ROOT}/lib/preflight.sh"

  trap install::on_interrupt INT TERM

  if [[ "${DRY_RUN}" == "1" ]]; then
    core::log DRY "Dry-run mode — no changes will be made"
  fi
  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  local modules=()
  if [[ -n "${TARGET_MODULE}" ]]; then
    if [[ ! -f "${DOTFILES_ROOT}/modules/${TARGET_MODULE}.sh" ]]; then
      core::log ERROR "Module not found: ${TARGET_MODULE}"
      printf 'Available:' >&2
      printf ' %s' "${_MODULE_ORDER[@]}" >&2
      printf '\n' >&2
      exit 1
    fi
    modules=("${TARGET_MODULE}")
  else
    modules=("${_MODULE_ORDER[@]}")
  fi

  preflight::scan_all "${TARGET_MODULE}"
  preflight::report

  local total=${#modules[@]} i=0 name
  for name in "${modules[@]}"; do
    i=$((i + 1))
    install::run_module "${name}" "${i}" "${total}"
  done

  core::log INFO "Install complete."
}

main "$@"
