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
  if core::check_installed go; then
    core::log INFO "Go already installed: $(go version)"
    core::summary "    ✓ $(go version) already installed"
    return 0
  fi

  local version tarball url
  version="$(_golang::latest_version)"
  tarball="$(_golang::tarball_name "${version}")"
  url="https://go.dev/dl/${tarball}"

  core::log INFO "Installing Go ${version} from ${url}"
  curl -fsSL "${url}" -o "/tmp/${tarball}"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "/tmp/${tarball}"
  rm "/tmp/${tarball}"

  core::log INFO "Go ${version} installed to /usr/local/go"
  core::summary "    ✓ installed Go ${version} from go.dev"

  # Activate for the rest of this install run.
  export PATH="${PATH}:/usr/local/go/bin:${HOME}/go/bin"

  # Persist for future login shells.
  core::ensure_block "${HOME}/.zprofile" "golang" \
    'export PATH="${PATH}:/usr/local/go/bin:${HOME}/go/bin"'
  core::summary "    ✓ config → ~/.zprofile (Go PATH)"
}

uninstall() {
  sudo rm -rf /usr/local/go
  core::remove_block "${HOME}/.zprofile" "golang"
  core::summary "    ✓ removed /usr/local/go"
  core::summary "    ✓ removed block from ~/.zprofile"
}
