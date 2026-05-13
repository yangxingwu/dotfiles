#!/usr/bin/env bash
# modules/golang.sh — Go programming language toolchain
# https://go.dev/doc/install
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="golang"
MODULE_DESC="Go programming language toolchain"
MODULE_PLATFORM="all"

# Detect the correct tarball name for the current platform.
_golang::tarball_name() {
  local os arch
  case "${DOTFILES_OS}" in
  mac) os="darwin" ;;
  linux) os="linux" ;;
  esac
  case "$(uname -m)" in
  x86_64) arch="amd64" ;;
  aarch64 | arm64) arch="arm64" ;;
  esac
  printf 'go%s.%s-%s.tar.gz' "${1}" "${os}" "${arch}"
}

# Fetch the latest stable Go version from go.dev.
_golang::latest_version() {
  curl -fsSL 'https://go.dev/VERSION?m=text' | head -1 | sed 's/^go//'
}

install() {
  if ! core::check_installed go; then
    local version tarball url
    version="$(_golang::latest_version)"
    tarball="$(_golang::tarball_name "${version}")"
    url="https://go.dev/dl/${tarball}"

    core::log INFO "Installing Go ${version} from ${url}"
    core::run_cmd "Downloading Go ${version}" curl -fsSL "${url}" -o "/tmp/${tarball}"
    sudo rm -rf /usr/local/go
    core::run_cmd "Extracting Go ${version}" sudo tar -C /usr/local -xzf "/tmp/${tarball}"
    rm "/tmp/${tarball}"

    core::summary "    ✓ installed Go ${version} from go.dev"
  else
    core::log INFO "Go already installed: $(go version)"
    core::summary "    ✓ $(go version) already installed"
  fi

  # Activate for the rest of this install run.
  export PATH="${PATH}:/usr/local/go/bin:${HOME}/go/bin"

  # Content is single-quoted: written literally to .zprofile, expanded by zsh at login.
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zprofile" "golang" \
    'export PATH="${PATH}:/usr/local/go/bin:${HOME}/go/bin"'
  core::summary "    ✓ config → ~/.zprofile (Go PATH)"
}

uninstall() {
  core::remove_block "${HOME}/.zprofile" "golang"
  core::summary "    ✓ removed block from ~/.zprofile"
}
