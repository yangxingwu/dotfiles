#!/usr/bin/env bash
# modules/zsh-config.sh — Shell environment, history, options, and aliases
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="zsh-config"
MODULE_DESC="Shell environment, history, options, and aliases"
MODULE_PLATFORM="all"
MODULE_DEPS=("cli-tools")

install() {
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "zsh-config" \
    '# Environment
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less -R"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# History
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="${HOME}/.zsh_history"

# Options
setopt share_history          # share history across all open terminals
setopt hist_ignore_all_dups   # remove older duplicate from history
setopt hist_reduce_blanks     # trim unnecessary whitespace before storing
setopt hist_verify            # show expanded history command before executing
setopt extended_history       # record timestamp and duration in history
setopt auto_cd                # type a directory name to cd into it
setopt interactive_comments   # allow # comments in interactive shell

# Aliases (guarded: only defined if target command exists)
command -v eza >/dev/null && alias ls='\''eza --icons --group-directories-first'\''
command -v eza >/dev/null && alias ll='\''eza -l --icons --git --group-directories-first'\''
command -v eza >/dev/null && alias la='\''eza -la --icons --git --group-directories-first'\''
command -v eza >/dev/null && alias lt='\''eza --tree --level=2 --icons'\''
command -v bat >/dev/null && alias cat='\''bat --paging=never'\'''
  core::log INFO "Configured shell environment, history, options, and aliases"
  core::summary "    ✓ config → ~/.zshrc (environment, history, options, aliases)"
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "zsh-config"
  core::summary "    ✓ removed zsh-config block from ~/.zshrc"
}
