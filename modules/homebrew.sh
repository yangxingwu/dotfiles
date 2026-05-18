#!/usr/bin/env bash
# modules/homebrew.sh — Homebrew shell environment (.zprofile block)
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="homebrew"
MODULE_DESC="Homebrew shell environment"
MODULE_PLATFORM="mac"

install() {
  local brew_prefix
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_prefix=/opt/homebrew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_prefix=/usr/local
  else
    core::log ERROR "brew binary not found at /opt/homebrew/bin/brew or /usr/local/bin/brew"
    return 1
  fi

  # Activate for the rest of this install run.
  eval "$("${brew_prefix}/bin/brew" shellenv)"

  # Persist for future login shells.
  # See: https://mirrors.ustc.edu.cn/help/brew.git.html
  #      https://mirrors.ustc.edu.cn/help/homebrew-bottles.html
  local block_content
  block_content="eval \"\$(${brew_prefix}/bin/brew shellenv)\""
  if [[ "${_CORE_MIRROR_CN}" == "true" ]]; then
    # Remote for the brew CLI repository itself (used by brew update)
    local brew_remote="https://mirrors.ustc.edu.cn/brew.git"
    # Remote for the package definition repository (used by brew update)
    local core_remote="https://mirrors.ustc.edu.cn/homebrew-core.git"
    # URL prefix for downloading prebuilt binary packages (used by brew install)
    local bottle_domain="https://mirrors.ustc.edu.cn/homebrew-bottles"
    # URL for the JSON API that lists available packages (used by brew search/info)
    local api_domain="https://mirrors.ustc.edu.cn/homebrew-bottles/api"

    block_content="${block_content}
export HOMEBREW_BREW_GIT_REMOTE=\"${brew_remote}\"
export HOMEBREW_CORE_GIT_REMOTE=\"${core_remote}\"
export HOMEBREW_BOTTLE_DOMAIN=\"${bottle_domain}\"
export HOMEBREW_API_DOMAIN=\"${api_domain}\""

    # Activate mirror for the rest of this install run.
    export HOMEBREW_BREW_GIT_REMOTE="${brew_remote}"
    export HOMEBREW_CORE_GIT_REMOTE="${core_remote}"
    export HOMEBREW_BOTTLE_DOMAIN="${bottle_domain}"
    export HOMEBREW_API_DOMAIN="${api_domain}"
    core::log INFO "Using USTC mirror for Homebrew"
  fi
  core::ensure_block "${HOME}/.zprofile" "homebrew" "${block_content}"
  core::summary "    ✓ config → ~/.zprofile (brew shellenv)"
}

uninstall() {
  core::remove_block "${HOME}/.zprofile" "homebrew"
  core::summary "    ✓ removed homebrew block from ~/.zprofile"
}
