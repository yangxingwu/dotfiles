#!/usr/bin/env bash
# modules/sheldon.sh — sheldon zsh plugin manager with curated plugin set
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="sheldon"
MODULE_DESC="sheldon plugin manager with curated plugin set"
MODULE_PLATFORM="all"

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

  local plugins=(
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-syntax-highlighting"
    "zsh-users/zsh-completions"
    "Aloxaf/fzf-tab"
    "mattmc3/zsh-safe-rm"
    "zsh-users/zsh-history-substring-search"
  )

  # sheldon add writes to plugins.toml (creates it if absent).
  # Errors on duplicate plugin names — silenced so re-runs are idempotent.
  local plugin name
  for plugin in "${plugins[@]}"; do
    name="${plugin##*/}"
    if [[ "${name}" == "zsh-completions" ]]; then
      sheldon add "${name}" --github "${plugin}" --apply fpath 2>/dev/null || true
    else
      sheldon add "${name}" --github "${plugin}" 2>/dev/null || true
    fi
  done

  # lock downloads plugin sources and generates the lock file.
  sheldon lock

  core::ensure_block "${HOME}/.zshrc" "sheldon" 'eval "$(sheldon source)"'
}

uninstall() {
  local plugins=(
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-syntax-highlighting"
    "zsh-users/zsh-completions"
    "Aloxaf/fzf-tab"
    "mattmc3/zsh-safe-rm"
    "zsh-users/zsh-history-substring-search"
  )

  local plugin name
  for plugin in "${plugins[@]}"; do
    name="${plugin##*/}"
    sheldon remove "${name}" 2>/dev/null || true
  done

  core::remove_block "${HOME}/.zshrc" "sheldon"
}
