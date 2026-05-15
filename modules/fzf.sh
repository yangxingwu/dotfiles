#!/usr/bin/env bash
# modules/fzf.sh — fzf fuzzy finder with fd/bat/eza integration
# Platform: all
#
# Configures:
#   - fzf binary installation
#   - Catppuccin Mocha theme (cloned from https://github.com/catppuccin/fzf)
#   - fd as default search source (respects .gitignore)
#   - bat as file preview for Ctrl+T
#   - eza as directory preview for Alt+C
#   - Layout defaults (height, reverse, border)
#   - Ctrl+R disabled (atuin handles history search)
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="fzf"
MODULE_DESC="fzf fuzzy finder with fd/bat/eza integration"
MODULE_PLATFORM="all"

_FZF_THEME_REPO="https://github.com/catppuccin/fzf.git"
_FZF_THEME_DIR="${HOME}/.local/share/fzf/catppuccin"

# Clone or update catppuccin/fzf theme repository.
_fzf::clone_theme() {
  if [[ -d "${_FZF_THEME_DIR}" ]]; then
    core::run_cmd "Updating fzf catppuccin theme" git -C "${_FZF_THEME_DIR}" pull --quiet
  else
    mkdir -p "$(dirname "${_FZF_THEME_DIR}")"
    core::run_cmd "Cloning fzf catppuccin theme" git clone --quiet "${_FZF_THEME_REPO}" "${_FZF_THEME_DIR}"
  fi
  core::summary "    ✓ catppuccin theme → ~/.local/share/fzf/catppuccin"
}

# Write fzf configuration block to .zshrc.
_fzf::write_config() {
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "fzf" \
    '# FZF configuration
# See: https://github.com/junegunn/fzf#environment-variables

# Catppuccin Mocha theme
# Source: https://github.com/catppuccin/fzf/blob/main/themes/catppuccin-fzf-mocha.sh
[[ -f "${HOME}/.local/share/fzf/catppuccin/themes/catppuccin-fzf-mocha.sh" ]] && \
  source "${HOME}/.local/share/fzf/catppuccin/themes/catppuccin-fzf-mocha.sh"

# Layout and behavior defaults
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} --height=60% --layout=reverse --border --info=inline"

# Use fd as default source (respects .gitignore, fast, hidden files included)
export FZF_DEFAULT_COMMAND='\''fd --type f --hidden --follow --exclude .git'\''

# Ctrl+T: file picker with bat preview
export FZF_CTRL_T_COMMAND='\''fd --type f --hidden --follow --exclude .git'\''
export FZF_CTRL_T_OPTS="--preview '\''bat --color=always --style=numbers --line-range :300 {}'\'' --select-1 --exit-0"

# Ctrl+R: disabled — atuin handles history search (runs after fzf in module order)
export FZF_CTRL_R_COMMAND=""

# Alt+C: directory jump with eza tree preview
export FZF_ALT_C_COMMAND='\''fd --type d --hidden --follow --exclude .git'\''
export FZF_ALT_C_OPTS="--preview '\''eza --tree --level=2 --color=always {}'\'' "

# Activate fzf key bindings and completion for zsh
eval "$(fzf --zsh)"'
  core::summary "    ✓ config → ~/.zshrc (fzf with fd/bat/eza/catppuccin)"
}

install() {
  core::run_cmd "Installing fzf" core::pkg_install fzf
  _fzf::clone_theme
  _fzf::write_config
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "fzf"
  core::summary "    ✓ removed fzf block from ~/.zshrc"

  rm -rf "${_FZF_THEME_DIR}"
  core::summary "    ✓ removed catppuccin theme clone"
}
