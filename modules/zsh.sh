#!/usr/bin/env bash
# modules/zsh.sh — Zsh configuration (sheldon plugin manager, starship prompt)
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="zsh"
MODULE_DESC="Zsh shell configuration (sheldon plugins, starship prompt)"
MODULE_PLATFORM="all"

LINKS=(
  "config/zsh/sheldon/plugins.toml:${HOME}/.config/sheldon/plugins.toml"
  "config/zsh/starship.toml:${HOME}/.config/starship.toml"
  "config/zsh/zshenv:${HOME}/.zshenv"
)

# Platform-specific .zshrc is expressed as an additional LINKS entry.
case "${DOTFILES_OS}" in
mac) LINKS+=("config/zsh/zshrc.mac:${HOME}/.zshrc") ;;
linux) LINKS+=("config/zsh/zshrc.linux:${HOME}/.zshrc") ;;
esac

install() {
  # macOS ships with a system zsh; Linux needs it explicitly.
  case "${DOTFILES_OS}" in
  mac) core::pkg_install sheldon starship ;;
  linux) core::pkg_install zsh sheldon starship ;;
  esac
}

uninstall() { :; }
