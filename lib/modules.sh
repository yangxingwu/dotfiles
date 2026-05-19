#!/usr/bin/env bash
# lib/modules.sh — Canonical module list for install.sh and uninstall.sh.
# Single source of truth: add/remove/reorder modules here.
# Order matters — see inline comments for dependency constraints.
set -euo pipefail
IFS=$'\n\t'

DOTFILES_MODULES=(
  homebrew             # mac only: .zprofile shellenv (must be first for brew PATH)
  font-hack-nerd-font
  ssh              # before git: SSH key needed for git commit signing
  rust             # before git/nvim: cargo for delta, tree-sitter-cli
  golang           # before git/nvim: go install lazygit
  git              # after ssh/rust/golang: needs SSH key, cargo, go
  cli-tools        # after rust/golang: cargo tools; before fzf: fzf preview uses bat/fd
  python           # after cli-tools: no hard deps; before fzf: logical grouping
  fzf              # before zoxide: zi interactive mode uses fzf
                   # before sheldon: sheldon's fzf-tab plugin requires the fzf binary
  zoxide
  sheldon
  atuin            # after rust (cargo), after sheldon (replaces its history-substring-search)
  starship
  ghostty          # after font/sheldon/zoxide/starship: config assumes these are installed
  nvim             # after rust (cargo), golang, git (lazygit), cli-tools (rg, fd)
  tmux
  zsh-config       # last: aliases depend on cli-tools (eza, bat), EDITOR depends on nvim
)

# DOTFILES_SELECTED_MODULES — modules actually scheduled for this run, in
# DOTFILES_MODULES order. Defaults to the full list; modules::filter narrows
# it. Orchestrators (install.sh / uninstall.sh) iterate this, not
# DOTFILES_MODULES, so the original list remains an immutable source of truth
# (used by --list and any future reporting).
DOTFILES_SELECTED_MODULES=("${DOTFILES_MODULES[@]}")

# modules::list_modules — print all available module names.
modules::list_modules() {
  printf 'Available modules:\n'
  local name
  for name in "${DOTFILES_MODULES[@]}"; do
    printf '  %s\n' "${name}"
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