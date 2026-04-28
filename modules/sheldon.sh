#!/usr/bin/env bash
# modules/sheldon.sh — sheldon zsh plugin manager with curated plugin set
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="sheldon"
MODULE_DESC="sheldon plugin manager with curated plugin set"
MODULE_PLATFORM="all"

# Plugin list shared by install and uninstall.
# zsh-completions is handled separately (needs --apply fpath).
_SHELDON_PLUGINS=(
  "zsh-users/zsh-autosuggestions"
  "zsh-users/zsh-syntax-highlighting"
  "Aloxaf/fzf-tab"
  "mattmc3/zsh-safe-rm"
  "zsh-users/zsh-history-substring-search"
)

install() {
  # sheldon is not in apt/dnf — install via cargo on all platforms for
  # consistency (brew has it but cargo keeps one code path).
  if ! core::check_installed sheldon; then
    if ! core::check_installed cargo; then
      core::log ERROR "cargo not found — install the rust module first"
      return 1
    fi
    cargo install sheldon --locked
    core::log INFO "sheldon installed"
  fi

  # No-op if config already exists.
  sheldon init --shell zsh

  # sheldon add writes to plugins.toml.
  # Errors on duplicate plugin names — silenced so re-runs are idempotent.
  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    sheldon add "${name}" --github "${plugin}" 2>/dev/null || true
  done
  # zsh-completions must use fpath instead of source to avoid permission errors.
  sheldon add zsh-completions --github zsh-users/zsh-completions --apply fpath 2>/dev/null || true

  # lock downloads plugin sources and generates the lock file.
  sheldon lock

  core::ensure_block "${HOME}/.zshrc" "sheldon" 'eval "$(sheldon source)"'
}

uninstall() {
  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    sheldon remove "${name}" 2>/dev/null || true
  done
  sheldon remove zsh-completions 2>/dev/null || true
  sheldon lock 2>/dev/null || true

  core::remove_block "${HOME}/.zshrc" "sheldon"
}
