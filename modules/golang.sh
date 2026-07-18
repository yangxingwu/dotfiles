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

# Fetch the sha256 published for a tarball in the Go download API.
# The API is served by both go.dev and golang.google.cn, so it honours
# --mirror-cn. Parsed with awk rather than jq because golang installs before
# cli-tools (which is where jq comes from) — jq is not on PATH yet. Each file
# object lists "sha256" right after "filename", so we latch onto the matching
# filename and print the first sha256 that follows.
_golang::expected_sha256() {
  local tarball="${1}" base_url="${2}"
  curl -fsSL "${base_url}/dl/?mode=json" | awk -v f="\"filename\": \"${tarball}\"" '
    index($0, f)                 { found = 1 }
    found && /"sha256":/          { gsub(/[",]/, ""); print $2; exit }
  '
}

# Compute the sha256 of a local file. Branches on OS like core::file_mode:
# macOS ships shasum (Perl), Linux ships sha256sum (coreutils).
_golang::file_sha256() {
  case "${DOTFILES_OS}" in
  mac) shasum -a 256 "${1}" | awk '{print $1}' ;;
  linux) sha256sum "${1}" | awk '{print $1}' ;;
  esac
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

    # Verify the download against the published sha256 before extracting into
    # /usr/local (a sudo operation) — HTTPS alone does not attest the bytes.
    local expected actual
    expected="$(_golang::expected_sha256 "${tarball}" "${base_url}")"
    if [[ -z "${expected}" ]]; then
      core::log ERROR "Could not fetch published sha256 for ${tarball}"
      rm -f "/tmp/${tarball}"
      return 1
    fi
    actual="$(_golang::file_sha256 "/tmp/${tarball}")"
    if [[ "${actual}" != "${expected}" ]]; then
      core::log ERROR "Checksum mismatch for ${tarball} (expected ${expected}, got ${actual})"
      rm -f "/tmp/${tarball}"
      return 1
    fi
    core::log INFO "Verified sha256: ${tarball}"
    core::summary "    ✓ verified sha256 (${tarball})"

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

  # Content written literally to .zshenv, expanded by zsh at load.
  local block_content
  block_content=$(cat <<'EOF'
case ":${PATH}:" in
  *:/usr/local/go/bin:*) ;;
  *) export PATH="/usr/local/go/bin:${PATH}" ;;
esac
case ":${PATH}:" in
  *:"${HOME}/go/bin":*) ;;
  *) export PATH="${HOME}/go/bin:${PATH}" ;;
esac
EOF
  )
  core::ensure_block "${HOME}/.zshenv" "golang" "${block_content}"
  core::summary "    ✓ config → ~/.zshenv (Go PATH)"
}

uninstall() {
  core::remove_block "${HOME}/.zshenv" "golang"
  # Reset Go env settings if configured.
  if command -v go >/dev/null 2>&1; then
    go env -u GO111MODULE 2>/dev/null || true
    go env -u GOPROXY 2>/dev/null || true
  fi
  core::summary "    ✓ removed block from ~/.zshenv"
  core::summary "    ✓ reset go env (GO111MODULE, GOPROXY)"
}
