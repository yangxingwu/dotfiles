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
#   - Ctrl+G: interactive ripgrep content search (rg + fzf + bat preview)
#   - Layout defaults (height, reverse, border)
#   - Ctrl+R disabled (atuin handles history search)
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="fzf"
MODULE_DESC="fzf fuzzy finder with fd/bat/eza integration"
MODULE_PLATFORM="all"
MODULE_DEPS=("cli-tools")

_FZF_THEME_REPO="https://github.com/catppuccin/fzf.git"
_FZF_THEME_DIR="${HOME}/.local/share/fzf/catppuccin"
_FZF_INIT_SCRIPT="${DOTFILES_CONFIG_DIR}/fzf.zsh"

# Clone or update catppuccin/fzf theme repository.
# catppuccin/fzf publishes no release tags, so we track main (theme drift is
# low-risk — colours only) but shallow-clone (--depth 1) to minimise download.
_fzf::clone_theme() {
  if [[ -d "${_FZF_THEME_DIR}" ]]; then
    core::run_cmd "Updating fzf catppuccin theme" git -C "${_FZF_THEME_DIR}" pull --quiet || return 1
  else
    mkdir -p "$(dirname "${_FZF_THEME_DIR}")"
    core::run_cmd "Cloning fzf catppuccin theme" git clone --quiet --depth 1 "${_FZF_THEME_REPO}" "${_FZF_THEME_DIR}" || return 1
  fi
  core::summary "    ✓ catppuccin theme → ~/.local/share/fzf/catppuccin"
}

# Write fzf configuration to ~/.config/dotfiles/fzf.zsh and source from .zshrc.
_fzf::write_config() {
  mkdir -p "${DOTFILES_CONFIG_DIR}"
  cat >"${_FZF_INIT_SCRIPT}" <<'FZF_CONFIG'
# fzf.zsh — fzf configuration managed by dotfiles
# See: https://github.com/junegunn/fzf#environment-variables

# Catppuccin Mocha theme
# Source: https://github.com/catppuccin/fzf/blob/main/themes/catppuccin-fzf-mocha.sh
[[ -f "${HOME}/.local/share/fzf/catppuccin/themes/catppuccin-fzf-mocha.sh" ]] && \
  source "${HOME}/.local/share/fzf/catppuccin/themes/catppuccin-fzf-mocha.sh"

# Layout and behavior defaults
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} --height=60% --layout=reverse --border --info=inline"

# Use fd as default source (respects .gitignore, fast, hidden files included)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# Ctrl+T: file picker with bat preview
export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :300 {}' --select-1 --exit-0"

# Ctrl+R: disabled — atuin handles history search (runs after fzf in module order)
export FZF_CTRL_R_COMMAND=""

# Alt+C: directory jump with eza tree preview
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}' "

# Activate fzf key bindings and completion for zsh
eval "$(fzf --zsh)"

# ── Ctrl+G: interactive ripgrep content search ──────────────────────────
# Uses the "Interactive Ripgrep" pattern from fzf official documentation:
#   https://github.com/junegunn/fzf/blob/master/ADVANCED.md#using-fzf-as-interactive-ripgrep-launcher
#
# How it works:
#   - fzf starts in "disabled" mode (no fuzzy filtering — rg does the searching)
#   - Every keystroke triggers rg to re-search with the current query
#   - Results shown with bat syntax-highlighted preview at the matching line
#   - Press Enter to open the file in nvim at the exact line number
#
# Key binding follows the same zsh widget pattern as fzf's own Ctrl+T/Alt+C:
#   1. Define function  2. Register as zle widget  3. bindkey
#   (See output of `fzf --zsh` for reference implementation)
fzf-grep-widget() {
  local RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
  local selected
  selected="$(
    fzf --ansi --disabled --query "" \
        --bind "start:reload:${RG_PREFIX} {q} || true" \
        --bind "change:reload:sleep 0.1; ${RG_PREFIX} {q} || true" \
        --delimiter : \
        --preview 'bat --color=always {1} --highlight-line {2}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
        --bind 'enter:become(echo {1} {2})'
  )"
  if [[ -n "${selected}" ]]; then
    local file line
    file="$(echo "${selected}" | awk '{print $1}')"
    line="$(echo "${selected}" | awk '{print $2}')"
    BUFFER="nvim +${line} ${file}"
    zle accept-line
  fi
  zle reset-prompt
}
zle -N fzf-grep-widget
bindkey '^G' fzf-grep-widget
FZF_CONFIG
  chmod 644 "${_FZF_INIT_SCRIPT}"
  core::log INFO "Wrote fzf config: ${_FZF_INIT_SCRIPT}"

  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "fzf" \
    'source "${HOME}/.config/dotfiles/fzf.zsh"'
  core::summary "    ✓ config → ~/.config/dotfiles/fzf.zsh"
  core::summary "    ✓ config → ~/.zshrc (source fzf.zsh)"
}

install() {
  core::pkg_install fzf || return 1
  _fzf::clone_theme || return 1
  _fzf::write_config || return 1
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "fzf"
  core::summary "    ✓ removed fzf block from ~/.zshrc"

  rm -f "${_FZF_INIT_SCRIPT}"
  core::log INFO "Removed ${_FZF_INIT_SCRIPT}"
  core::summary "    ✓ removed ~/.config/dotfiles/fzf.zsh"

  rm -rf "${_FZF_THEME_DIR}"
  core::log INFO "Removed catppuccin theme: ${_FZF_THEME_DIR}"
  core::summary "    ✓ removed catppuccin theme clone"
}
