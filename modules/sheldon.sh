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
_SHELDON_PLUGINS=(
  "zsh-users/zsh-autosuggestions"
  "zsh-users/zsh-syntax-highlighting"
  "zsh-users/zsh-completions"
  "Aloxaf/fzf-tab"
  "mattmc3/zsh-safe-rm"
)

install() {
  # sheldon is not in apt/dnf — install via cargo on all platforms for
  # consistency (brew has it but cargo keeps one code path).
  if ! core::check_installed sheldon; then
    if ! core::check_installed cargo; then
      core::log ERROR "cargo not found — install the rust module first"
      return 1
    fi
    core::run_cmd "Installing sheldon" cargo install sheldon --locked
    core::summary "    ✓ installed via cargo"
  else
    core::summary "    ✓ sheldon already installed"
  fi

  # Initialize config if absent. sheldon init prompts [y/N] interactively,
  # so pipe 'y' to handle non-interactive environments (CI).
  core::run_cmd "Initializing sheldon" bash -c 'printf "y\n" | sheldon init --shell zsh'

  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    # zsh-completions must use fpath instead of source to avoid permission errors.
    if [[ "${name}" == "zsh-completions" ]]; then
      core::run_cmd "Adding plugin ${name}" sheldon add "${name}" --github "${plugin}" --apply fpath
    else
      core::run_cmd "Adding plugin ${name}" sheldon add "${name}" --github "${plugin}"
    fi
  done

  core::run_cmd "Locking sheldon plugins" sheldon lock --update

  local plugin_names=""
  local p
  for p in "${_SHELDON_PLUGINS[@]}"; do
    plugin_names="${plugin_names:+${plugin_names}, }${p##*/}"
  done
  core::summary "    ✓ plugins: ${plugin_names}"

  # Content is single-quoted: written literally to .zshrc, expanded by zsh at login.
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "sheldon" \
    'eval "$(sheldon source)"
# zsh-completions plugin only adds fpath entries (completion definition dirs).
# compinit must run after sheldon to actually register those completions.
autoload -Uz compinit && compinit'
  core::summary "    ✓ config → ~/.zshrc (sheldon source, compinit)"
}

uninstall() {
  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    core::run_cmd "Removing plugin ${name}" sheldon remove "${name}"
  done
  core::run_cmd "Locking sheldon plugins" sheldon lock --update

  core::remove_block "${HOME}/.zshrc" "sheldon"
  core::summary "    ✓ removed plugins and block from ~/.zshrc"
}
