#!/usr/bin/env bash
# modules/sheldon.sh — sheldon zsh plugin manager with curated plugin set
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="sheldon"
MODULE_DESC="sheldon plugin manager with curated plugin set"
MODULE_PLATFORM="all"

_SHELDON_PLUGINS=(
  "zsh-users/zsh-autosuggestions"
  "zsh-users/zsh-syntax-highlighting"
  "zsh-users/zsh-completions"
  "Aloxaf/fzf-tab"
  "mattmc3/zsh-safe-rm"
  "zsh-users/zsh-history-substring-search"
)

install() {
  _sheldon::install_binary

  local config="${HOME}/.config/sheldon/plugins.toml"
  if [[ ! -f "${config}" ]]; then
    sheldon init --shell zsh
  fi

  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    # --apply fpath for zsh-completions; source (default) for everything else.
    if [[ "${name}" == "zsh-completions" ]]; then
      sheldon add "${name}" --github "${plugin}" --apply fpath 2>/dev/null || true
    else
      sheldon add "${name}" --github "${plugin}" 2>/dev/null || true
    fi
  done

  core::ensure_block "${HOME}/.zshrc" "sheldon" 'eval "$(sheldon source)"'
  core::ensure_block "${HOME}/.zshrc" "compinit" 'autoload -Uz compinit && compinit'
  core::ensure_block "${HOME}/.zshrc" "history-substring-search" \
    'bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down'
}

uninstall() {
  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    sheldon remove "${name}" 2>/dev/null || true
  done

  core::remove_block "${HOME}/.zshrc" "history-substring-search"
  core::remove_block "${HOME}/.zshrc" "compinit"
  core::remove_block "${HOME}/.zshrc" "sheldon"
}

# Install sheldon binary. brew on macOS, cargo on Linux.
_sheldon::install_binary() {
  if core::check_installed sheldon; then
    core::log INFO "sheldon already installed"
    return 0
  fi

  case "${DOTFILES_OS}" in
  mac)
    core::pkg_install sheldon
    ;;
  linux)
    if ! core::check_installed cargo; then
      core::log ERROR "cargo not found — install the rust module first"
      return 1
    fi
    cargo install sheldon --locked
    ;;
  esac
  core::log INFO "sheldon installed"
}
