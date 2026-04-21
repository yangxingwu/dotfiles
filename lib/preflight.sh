#!/usr/bin/env bash
# lib/preflight.sh — Full conflict scan engine.
# Scans all module LINKS[] before any changes are made; presents a unified conflict
# report; prompts user for resolution strategy (backup all / skip all / per item).
# Requires: DOTFILES_ROOT, core.sh sourced, DOTFILES_OS set.
set -euo pipefail
IFS=$'\n\t'

# _PREFLIGHT_CONFLICTS entries: "module_name|src|target"
_PREFLIGHT_CONFLICTS=()
# PREFLIGHT_SKIP_MODULES: modules to skip during install (populated by resolution)
PREFLIGHT_SKIP_MODULES=()

# preflight::scan_module <module-file>
# Sources module in a subshell, checks each LINKS[] entry for conflicts.
# Prints conflict lines to stdout: "module_name|src|target"
preflight::scan_module() {
  local module_file="${1}"

  (
    # shellcheck source=/dev/null
    source "${module_file}"

    # Skip if wrong platform
    if [[ "${MODULE_PLATFORM}" != "all" ]] \
      && [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
      return 0
    fi

    local link_entry src target abs_src
    for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
      src="${link_entry%%:*}"
      target="${link_entry##*:}"
      abs_src="${DOTFILES_ROOT}/${src}"

      # Already correctly linked — not a conflict
      if [[ -L "${target}" ]] \
        && [[ "$(readlink "${target}")" == "${abs_src}" ]]; then
        continue
      fi

      # Conflict: target exists as anything (file, directory, or wrong symlink)
      if [[ -e "${target}" ]] || [[ -L "${target}" ]]; then
        printf '%s|%s|%s\n' "${MODULE_NAME}" "${src}" "${target}"
      fi
    done
  )
}

# preflight::scan_all
# Iterates all modules/*.sh files and collects conflicts into _PREFLIGHT_CONFLICTS.
preflight::scan_all() {
  local modules_dir="${DOTFILES_ROOT}/modules"
  _PREFLIGHT_CONFLICTS=()

  local module_file conflict
  for module_file in "${modules_dir}"/*.sh; do
    [[ -f "${module_file}" ]] || continue
    while IFS= read -r conflict; do
      [[ -n "${conflict}" ]] && _PREFLIGHT_CONFLICTS+=("${conflict}")
    done < <(preflight::scan_module "${module_file}")
  done
}

# preflight::report
# Prints conflict table and prompts user to choose resolution strategy.
# No-op if there are no conflicts.
preflight::report() {
  if [[ ${#_PREFLIGHT_CONFLICTS[@]} -eq 0 ]]; then
    core::log INFO "Preflight: no conflicts"
    return 0
  fi

  printf '\n%s\n' "── Conflicts detected ──────────────────────────────────────"
  printf '  %-14s  %-34s  %s\n' "MODULE" "SOURCE" "TARGET"
  printf '  %-14s  %-34s  %s\n' "--------------" "----------------------------------" "------"

  local conflict module src target
  for conflict in "${_PREFLIGHT_CONFLICTS[@]}"; do
    module="${conflict%%|*}"
    src="${conflict#*|}"
    src="${src%%|*}"
    target="${conflict##*|}"
    printf '  %-14s  %-34s  %s\n' "${module}" "${src}" "${target}"
  done

  printf '%s\n\n' "────────────────────────────────────────────────────────────"
  printf 'Resolve conflicts:\n'
  printf '  [b] Backup all conflicting targets and continue\n'
  printf '  [s] Skip all conflicting modules\n'
  printf '  [d] Decide per item\n'
  printf '  [q] Quit\n'
  printf '\nChoice: '

  local choice
  read -r choice
  case "${choice}" in
    b) preflight::_resolve_backup_all ;;
    s) preflight::_resolve_skip_all ;;
    d) preflight::_resolve_per_item ;;
    q) printf 'Aborted.\n'; exit 0 ;;
    *)
      printf 'error: invalid choice\n' >&2
      exit 1
      ;;
  esac
}

preflight::_resolve_backup_all() {
  local conflict target
  for conflict in "${_PREFLIGHT_CONFLICTS[@]}"; do
    target="${conflict##*|}"
    core::backup "${target}"
  done
}

preflight::_resolve_skip_all() {
  local conflict module
  for conflict in "${_PREFLIGHT_CONFLICTS[@]}"; do
    module="${conflict%%|*}"
    PREFLIGHT_SKIP_MODULES+=("${module}")
  done
  core::log WARN "Skipping modules: ${PREFLIGHT_SKIP_MODULES[*]}"
}

preflight::_resolve_per_item() {
  local conflict module target choice
  for conflict in "${_PREFLIGHT_CONFLICTS[@]}"; do
    module="${conflict%%|*}"
    target="${conflict##*|}"

    printf '\nConflict: %s  (module: %s)\n' "${target}" "${module}"
    printf '  [b] Backup this target\n'
    printf '  [s] Skip this module\n'
    printf '  [q] Quit\n'
    printf 'Choice: '
    read -r choice

    case "${choice}" in
      b) core::backup "${target}" ;;
      s) PREFLIGHT_SKIP_MODULES+=("${module}") ;;
      q) printf 'Aborted.\n'; exit 0 ;;
      *)
        printf 'warn: invalid choice — skipping module %s\n' "${module}" >&2
        PREFLIGHT_SKIP_MODULES+=("${module}")
        ;;
    esac
  done
}

# preflight::is_skipped <module-name>
# Returns 0 (true) if the module is in the skip list; 1 (false) otherwise.
preflight::is_skipped() {
  local module="${1}"
  local skipped
  for skipped in "${PREFLIGHT_SKIP_MODULES[@]+"${PREFLIGHT_SKIP_MODULES[@]}"}"; do
    [[ "${skipped}" == "${module}" ]] && return 0
  done
  return 1
}
