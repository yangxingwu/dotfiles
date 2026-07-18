#!/usr/bin/env bash
# modules/sheldon.sh — sheldon zsh plugin manager with curated plugin set
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="sheldon"
MODULE_DESC="sheldon plugin manager with curated plugin set"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust")

_SHELDON_CONFIG="${HOME}/.config/sheldon/plugins.toml"

install() {
  # sheldon is not in apt/dnf — install via cargo on all platforms for
  # consistency (brew has it but cargo keeps one code path).
  if ! core::check_installed sheldon; then
    if ! core::check_installed cargo; then
      core::log ERROR "cargo not found — install the rust module first"
      return 1
    fi
    core::run_cmd "Installing sheldon" cargo install --locked sheldon || return 1
    core::summary "    ✓ installed via cargo"
  else
    core::log INFO "sheldon already installed"
    core::summary "    ✓ sheldon already installed"
  fi

  # Write plugin config (declarative — always overwrites to desired state).
  mkdir -p "$(dirname "${_SHELDON_CONFIG}")"
  cat >"${_SHELDON_CONFIG}" <<'TOML'
shell = "zsh"

[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"

[plugins.zsh-syntax-highlighting]
github = "zsh-users/zsh-syntax-highlighting"

[plugins.zsh-completions]
github = "zsh-users/zsh-completions"
apply = ["fpath"]

[plugins.fzf-tab]
github = "Aloxaf/fzf-tab"

[plugins.zsh-safe-rm]
github = "mattmc3/zsh-safe-rm"
TOML
  core::log INFO "Wrote sheldon config → ${_SHELDON_CONFIG}"

  core::run_cmd "Locking sheldon plugins" sheldon lock --update || return 1
  core::summary "    ✓ plugins: zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, fzf-tab, zsh-safe-rm"

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
  rm -rf "${HOME}/.config/sheldon" "${HOME}/.local/share/sheldon"
  core::log INFO "Removed sheldon config and plugin data"
  core::remove_block "${HOME}/.zshrc" "sheldon"
  core::summary "    ✓ removed ~/.config/sheldon"
  core::summary "    ✓ removed ~/.local/share/sheldon"
  core::summary "    ✓ removed sheldon block from ~/.zshrc"
}
