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
  "config/zsh/zshenv:${HOME}/.zshenv"
)

pre_install() {
  # Must run before LINKS so ln -sf doesn't silently overwrite existing files.
  [[ -f "${HOME}/.zshenv" && ! -L "${HOME}/.zshenv" ]] && core::backup "${HOME}/.zshenv"
}

install() {
  # macOS ships with a system zsh; Linux needs it explicitly.
  case "${DOTFILES_OS}" in
    mac)   core::pkg_install sheldon starship ;;
    linux) core::pkg_install zsh sheldon starship ;;
  esac
}

post_install() {
  # Back up existing non-symlink files before taking ownership.
  # The user can then migrate machine-specific lines to ~/.zshrc.local / ~/.zshenv.local.
  [[ -f "${HOME}/.zshrc" && ! -L "${HOME}/.zshrc" ]] && core::backup "${HOME}/.zshrc"

  # Symlink platform-specific zshrc.
  case "${DOTFILES_OS}" in
    mac)   core::symlink "config/zsh/zshrc.mac"   "${HOME}/.zshrc" ;;
    linux) core::symlink "config/zsh/zshrc.linux" "${HOME}/.zshrc" ;;
  esac

  # Generate starship config from the catppuccin-powerline preset.
  # The preset is the unmodified upstream — no point tracking it in the repo.
  local starship_cfg="${HOME}/.config/starship.toml"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would run: starship preset catppuccin-powerline -o ${starship_cfg}"
    return 0
  fi

  mkdir -p "$(dirname "${starship_cfg}")"
  starship preset catppuccin-powerline -o "${starship_cfg}"
  core::log INFO "Generated starship config from catppuccin-powerline preset"
}
