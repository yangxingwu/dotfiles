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

# Fetch the latest stable Go version.
# Uses golang.google.cn when --mirror-cn is set.
# See: https://goproxy.cn
_golang::latest_version() {
  local base_url="https://go.dev"
  [[ "${_CORE_MIRROR_CN:-}" == "true" ]] && base_url="https://golang.google.cn"
  curl -fsSL "${base_url}/VERSION?m=text" | head -1 | sed 's/^go//'
}

install() {
  if ! core::check_installed go; then
    local version tarball url base_url
    base_url="https://go.dev"
    [[ "${_CORE_MIRROR_CN:-}" == "true" ]] && base_url="https://golang.google.cn"

    version="$(_golang::latest_version)"
    tarball="$(_golang::tarball_name "${version}")"
    url="${base_url}/dl/${tarball}"

    core::log INFO "Installing Go ${version} from ${url}"
    core::run_cmd "Downloading Go ${version}" curl -fsSL "${url}" -o "/tmp/${tarball}" || return 1
    sudo rm -rf /usr/local/go
    core::run_cmd "Extracting Go ${version}" sudo tar -C /usr/local -xzf "/tmp/${tarball}" || return 1
    rm "/tmp/${tarball}"

    core::summary "    ✓ installed Go ${version} from ${base_url}"
  else
    core::log INFO "Go already installed: $(go version)"
    core::summary "    ✓ $(go version) already installed"
  fi

  # Activate for the rest of this install run.
  export PATH="${PATH}:/usr/local/go/bin:${HOME}/go/bin"

  # Set GOPROXY for China mirror if requested.
  # See: https://goproxy.cn
  if [[ "${_CORE_MIRROR_CN:-}" == "true" ]]; then
    go env -w GO111MODULE=on
    go env -w GOPROXY=https://goproxy.cn,direct
    core::log INFO "Set GOPROXY=https://goproxy.cn,direct"
    core::summary "    ✓ config → go env (GOPROXY=goproxy.cn)"
  fi

  # Content is single-quoted: written literally to .zprofile, expanded by zsh at login.
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zprofile" "golang" \
    'export PATH="${PATH}:/usr/local/go/bin:${HOME}/go/bin"'
  core::summary "    ✓ config → ~/.zprofile (Go PATH)"
}

uninstall() {
  core::remove_block "${HOME}/.zprofile" "golang"
  # Reset Go env settings if configured.
  if command -v go >/dev/null 2>&1; then
    go env -u GO111MODULE 2>/dev/null || true
    go env -u GOPROXY 2>/dev/null || true
  fi
  core::summary "    ✓ removed block from ~/.zprofile"
  core::summary "    ✓ reset go env (GO111MODULE, GOPROXY)"
}
