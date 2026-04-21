#!/usr/bin/env bash
# modules/zsh.sh — Zsh configuration (sheldon plugin manager, starship prompt)
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="zsh"
MODULE_DESC="Zsh shell configuration (sheldon plugins, starship prompt)"
MODULE_PLATFORM="all"

# NOTE: .zshrc is managed separately; this module only links plugin/prompt configs.
LINKS=(
  "config/zsh/sheldon/plugins.toml:${HOME}/.config/sheldon/plugins.toml"
)

DEPS_MAC=("sheldon" "starship")
DEPS_LINUX=("zsh" "sheldon" "starship")

pre_install() { :; }

post_install() {
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
