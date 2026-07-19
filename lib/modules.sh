#!/usr/bin/env bash
# lib/modules.sh — Canonical module list for install.sh and uninstall.sh.
# Single source of truth: add/remove/reorder modules here.
# Order matters — see inline comments for dependency constraints.
set -euo pipefail
IFS=$'\n\t'

DOTFILES_MODULES=(
  homebrew # mac only: .zshrc shellenv (must be first for brew PATH)
  font-hack-nerd-font
  ssh       # before git: SSH key needed for git commit signing
  rust      # before git/nvim: cargo for delta, tree-sitter-cli
  golang    # before git/nvim: go install lazygit
  git       # after ssh/rust/golang: needs SSH key, cargo, go
  cli-tools # after rust/golang: cargo tools; before fzf: fzf preview uses bat/fd
  python    # after cli-tools: no hard deps; before fzf: logical grouping
  nodejs    # after rust (cargo install fnm); before nvim (npm install -g neovim)
  fzf       # before zoxide: zi interactive mode uses fzf
  # before sheldon: sheldon's fzf-tab plugin requires the fzf binary
  zoxide
  sheldon
  atuin # after rust (cargo), after sheldon (replaces its history-substring-search)
  starship
  ghostty # after font/sheldon/zoxide/starship: config assumes these are installed
  nvim    # after rust (cargo), golang, git (lazygit), cli-tools (rg, fd)
  zellij
  zsh-config # last: aliases depend on cli-tools (eza, bat), EDITOR depends on nvim
)

# DOTFILES_SELECTED_MODULES — modules actually scheduled for this run, in
# DOTFILES_MODULES order. Defaults to the full list; modules::filter narrows
# it. Orchestrators (install.sh / uninstall.sh) iterate this, not
# DOTFILES_MODULES, so the original list remains an immutable source of truth
# (used by --list and any future reporting).
DOTFILES_SELECTED_MODULES=("${DOTFILES_MODULES[@]}")

# modules::list_modules — print every module with its platform and install status.
# MODULE_PLATFORM is read by sourcing each module in a subshell, so the module's
# variables and install/uninstall definitions don't leak into this shell. The
# timestamp comes from the status file written by core::module_installed; it is
# refreshed on every successful install, so it reflects the most recent
# install/update time.
# shellcheck disable=SC2154  # DOTFILES_ROOT (entrypoint) and _CORE_STATUS_FILE (core.sh) are set before this runs
modules::list_modules() {
  local total=${#DOTFILES_MODULES[@]} installed=0
  local name platform ts disp
  local -a rows=()

  for name in "${DOTFILES_MODULES[@]}"; do
    platform="$(
      # shellcheck source=/dev/null
      source "${DOTFILES_ROOT}/modules/${name}.sh" >/dev/null 2>&1
      printf '%s' "${MODULE_PLATFORM:-?}"
    )"

    # awk (not grep | awk): a not-installed module has no match, and grep would
    # return 1 there — under the entrypoint's set -e + pipefail that aborts --list.
    # awk matches to empty and exits 0. The -f guard uses `if` (not `&&`) so a
    # missing status file also can't trip set -e.
    ts=""
    if [[ -f "${_CORE_STATUS_FILE}" ]]; then
      ts="$(awk -v m="${name}" '$1 == m {print $2}' "${_CORE_STATUS_FILE}")"
    fi
    if [[ -n "${ts}" ]]; then
      installed=$((installed + 1))
      disp="${ts/T/ }"  # ISO 'T' → space
      disp="${disp%:*}" # drop seconds
      rows+=("$(printf '  %-20s %-9s ✓ %s' "${name}" "${platform}" "${disp}")")
    else
      rows+=("$(printf '  %-20s %-9s — not installed' "${name}" "${platform}")")
    fi
  done

  printf 'Modules (%d / %d installed) — ✓ shows the last install/update time\n\n' "${installed}" "${total}"
  printf '  %-20s %-9s %s\n' "MODULE" "PLATFORM" "STATUS"
  local row
  for row in "${rows[@]}"; do
    printf '%s\n' "${row}"
  done
}

# modules::filter <mode> <csv> — narrow DOTFILES_SELECTED_MODULES in place.
#
#   mode : "only" keeps modules in <csv>; anything else (i.e. "skip") drops
#          modules in <csv>. Caller guarantees mode is "only" or "skip".
#   csv  : comma-separated module names (e.g. "ssh,git,rust"); may be empty.
#
# Returns 1 on the first invalid token (empty / duplicate / unknown). On
# success, DOTFILES_SELECTED_MODULES is rewritten in DOTFILES_MODULES order.
# DOTFILES_MODULES is never modified.
modules::filter() {
  local mode="${1}" csv="${2-}"

  # Two name sets, both populated below:
  #   valid    — every name that exists in DOTFILES_MODULES
  #   selected — names parsed from <csv> (after validation)
  local -A valid=() selected=()
  local name

  for name in "${DOTFILES_MODULES[@]}"; do
    valid[${name}]=1
  done

  # Parse and validate <csv>.
  local -a tokens=()
  [[ -n "${csv}" ]] && IFS=',' read -ra tokens <<<"${csv}"

  for name in "${tokens[@]}"; do
    if [[ -z "${name}" ]]; then
      printf 'error: empty module name (check for stray commas)\n' >&2
      return 1
    fi
    if [[ -v selected[${name}] ]]; then
      printf 'error: duplicate module: %s\n' "${name}" >&2
      return 1
    fi
    if [[ ! -v valid[${name}] ]]; then
      printf 'error: unknown module: %s\n' "${name}" >&2
      printf 'Run with --list to see available modules.\n' >&2
      return 1
    fi
    selected[${name}]=1
  done

  # Walk DOTFILES_MODULES in order and keep each name per <mode>. Hoisting
  # the mode check out of the loop body makes each branch's rule self-evident.
  local -a result=()
  case "${mode}" in
  only)
    for name in "${DOTFILES_MODULES[@]}"; do
      [[ -v selected[${name}] ]] && result+=("${name}")
    done
    ;;
  skip)
    for name in "${DOTFILES_MODULES[@]}"; do
      [[ ! -v selected[${name}] ]] && result+=("${name}")
    done
    ;;
  esac
  # shellcheck disable=SC2034  # read by install.sh / uninstall.sh after sourcing
  DOTFILES_SELECTED_MODULES=("${result[@]}")
}
