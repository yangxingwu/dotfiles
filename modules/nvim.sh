#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor with LazyVim configuration
# https://github.com/neovim/neovim
# https://www.lazyvim.org
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nvim"
MODULE_DESC="Neovim editor with LazyVim configuration (yangxingwu/neovim-lua-config)"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust" "golang" "git" "cli-tools" "python" "nodejs")

# Source directory for lua/luarocks compiled from source.
_NVIM_SRC_DIR="${HOME}/.local/src"

# Versions used by install and uninstall — single source of truth.
_NVIM_LUA_VERSION="5.1.5"
_NVIM_LUAROCKS_VERSION="3.13.0"

# Install Lua 5.1 from source to /usr/local.
# luarocks requires lua 5.1 because neovim uses LuaJIT (5.1 compatible)
# and rocks must be compiled against the same lua version.
_nvim::install_lua51_from_src() {
  if [[ -x /usr/local/bin/lua ]] && /usr/local/bin/lua -v 2>&1 | grep -q "Lua 5.1"; then
    core::log INFO "Lua 5.1 already installed (/usr/local/bin/lua)"
    core::summary "    ✓ Lua 5.1 already installed"
    return 0
  fi

  local url="https://www.lua.org/ftp/lua-${_NVIM_LUA_VERSION}.tar.gz"
  local src_dir="${_NVIM_SRC_DIR}/lua-${_NVIM_LUA_VERSION}"

  # Lua's Makefile requires a platform target (no default build).
  local platform
  case "${DOTFILES_OS}" in
  mac) platform="macosx" ;;
  linux) platform="linux" ;;
  esac

  mkdir -p "${_NVIM_SRC_DIR}"
  core::run_cmd "Downloading Lua ${_NVIM_LUA_VERSION}" curl -sSL "${url}" -o "${_NVIM_SRC_DIR}/lua-${_NVIM_LUA_VERSION}.tar.gz" || return 1
  tar -xzf "${_NVIM_SRC_DIR}/lua-${_NVIM_LUA_VERSION}.tar.gz" -C "${_NVIM_SRC_DIR}"
  rm -f "${_NVIM_SRC_DIR}/lua-${_NVIM_LUA_VERSION}.tar.gz"

  # Lua's readline integration requires development headers on Linux.
  # macOS provides readline.h via Xcode CLT SDK sysroot
  # (/Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk/usr/include/readline/),
  # which clang finds implicitly through -isysroot — no explicit install needed.
  if [[ "${DOTFILES_OS}" == "linux" ]]; then
    case "${DOTFILES_PKG_MANAGER}" in
    apt) core::pkg_install libreadline-dev || return 1 ;;
    dnf) core::pkg_install readline-devel || return 1 ;;
    esac
  fi

  core::run_cmd "Compiling Lua ${_NVIM_LUA_VERSION}" make -C "${src_dir}" "${platform}" || return 1
  core::run_cmd "Installing Lua ${_NVIM_LUA_VERSION}" sudo make -C "${src_dir}" install || return 1
  core::summary "    ✓ Lua ${_NVIM_LUA_VERSION} installed to /usr/local"
}

# Install luarocks from source, configured against lua 5.1 in /usr/local.
# Called when the system package manager does not provide a compatible luarocks.
_nvim::install_luarocks_from_src() {
  # luarocks must be linked against lua 5.1 (LuaJIT-compatible).
  # A luarocks built for 5.3/5.4 will produce incompatible rocks.
  if command -v luarocks >/dev/null 2>&1; then
    local lua_ver
    lua_ver="$(luarocks config lua_version 2>/dev/null || true)"
    if [[ "${lua_ver}" == "5.1" ]]; then
      core::log INFO "luarocks already installed (lua ${lua_ver})"
      core::summary "    ✓ luarocks already installed (lua ${lua_ver})"
      return 0
    fi
    core::log WARN "luarocks found but linked to lua ${lua_ver:-unknown}, need 5.1 — rebuilding"
  fi

  local url="https://luarocks.org/releases/luarocks-${_NVIM_LUAROCKS_VERSION}.tar.gz"
  local src_dir="${_NVIM_SRC_DIR}/luarocks-${_NVIM_LUAROCKS_VERSION}"

  mkdir -p "${_NVIM_SRC_DIR}"
  core::run_cmd "Downloading luarocks ${_NVIM_LUAROCKS_VERSION}" curl -sSL "${url}" -o "${_NVIM_SRC_DIR}/luarocks-${_NVIM_LUAROCKS_VERSION}.tar.gz" || return 1
  tar -xzf "${_NVIM_SRC_DIR}/luarocks-${_NVIM_LUAROCKS_VERSION}.tar.gz" -C "${_NVIM_SRC_DIR}"
  rm -f "${_NVIM_SRC_DIR}/luarocks-${_NVIM_LUAROCKS_VERSION}.tar.gz"

  (
    cd "${src_dir}"
    core::run_cmd "Configuring luarocks" ./configure --with-lua=/usr/local || exit 1
    core::run_cmd "Compiling luarocks" make || exit 1
    core::run_cmd "Installing luarocks" sudo make install || exit 1
  ) || return 1
  core::summary "    ✓ luarocks ${_NVIM_LUAROCKS_VERSION} installed to /usr/local"
}

# Install LazyVim requirements.
# https://www.lazyvim.org/ — Requirements section.
_nvim::install_deps() {
  # rg and fd are provided by the cli-tools module (runs before nvim).
  case "${DOTFILES_OS}" in
  mac)
    core::pkg_install shfmt shellcheck || return 1
    ;;
  linux)
    # libsqlite3: Snacks.picker loads libsqlite3.so via LuaJIT FFI for
    # frecency/history (macOS has it built-in via system dylib).
    local sqlite_pkg="libsqlite3-dev"
    [[ "${DOTFILES_PKG_MANAGER}" == "dnf" ]] && sqlite_pkg="sqlite-devel"
    core::pkg_install shellcheck "${sqlite_pkg}" || return 1

    # shfmt: not available in CentOS/RHEL repos. golang module is a
    # dependency so go install is always available.
    if core::check_installed shfmt; then
      core::log INFO "shfmt already installed"
      core::summary "    ✓ shfmt already installed"
    else
      core::run_cmd "Installing shfmt" go install mvdan.cc/sh/v3/cmd/shfmt@latest || return 1
      core::summary "    ✓ shfmt installed via go install"
    fi
    ;;
  esac

  # lua 5.1 + luarocks: neovim uses LuaJIT (lua 5.1 compatible). luarocks
  # must link to lua 5.1 to compile compatible rocks. Always compile from
  # source to guarantee consistent /usr/local prefix for both.
  _nvim::install_lua51_from_src || return 1
  _nvim::install_luarocks_from_src || return 1

  # lazygit is provided by the git module (runs before nvim).
  # tree-sitter-cli is not in apt/dnf; rust module ensures cargo is on PATH.
  if core::check_installed tree-sitter; then
    core::log INFO "tree-sitter-cli already installed"
    core::summary "    ✓ tree-sitter-cli already installed"
  else
    core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli || return 1
    core::summary "    ✓ tree-sitter-cli installed via cargo"
  fi

  # Python provider (`:help provider-python`).
  if [[ "${DOTFILES_PKG_MANAGER}" == "dnf" ]]; then
    # Fedora's neovim RPM sets g:python3_host_prog=/usr/bin/python3 in system
    # config, bypassing pipx's pynvim-python auto-detection. Use the distro
    # package (PEP 668 blocks pip --user on Fedora 38+).
    core::pkg_install python3-neovim || return 1
  else
    # pynvim 0.6.0+ installed via pipx is auto-detected by neovim.
    if command -v pynvim-python >/dev/null 2>&1; then
      core::log INFO "pynvim already installed"
      core::summary "    ✓ pynvim already installed"
    else
      core::run_cmd "Installing pynvim" pipx install pynvim || return 1
      core::summary "    ✓ pynvim installed via pipx"
    fi
  fi

  # Node.js provider (`:help provider-nodejs`).
  # Use `fnm exec` to explicitly call fnm-managed npm, bypassing any system
  # npm that may exist (e.g. Fedora's neovim RPM pulls in system nodejs22
  # whose npm global prefix requires root).
  if fnm exec --using=lts-latest npm list -g neovim >/dev/null 2>&1; then
    core::log INFO "neovim npm package already installed"
    core::summary "    ✓ neovim npm package already installed"
  else
    core::run_cmd "Installing neovim npm package" fnm exec --using=lts-latest npm install -g neovim || return 1
  fi
}

# Build and install Neovim from source when repo version is insufficient.
# Follows https://github.com/neovim/neovim/blob/master/BUILD.md
# Source kept at ~/.local/src/neovim for uninstall (sudo make uninstall).
_nvim::install_from_src() {
  local src_dir="${_NVIM_SRC_DIR}/neovim"

  # Clean previous source if present.
  rm -rf "${src_dir}"
  mkdir -p "${_NVIM_SRC_DIR}"

  core::run_cmd "Cloning neovim source" git clone https://github.com/neovim/neovim.git "${src_dir}" || return 1

  (
    cd "${src_dir}"
    core::run_cmd "Checking out stable branch" git checkout stable || exit 1
    core::run_cmd "Building neovim" make CMAKE_BUILD_TYPE=RelWithDebInfo || exit 1
    core::run_cmd "Installing neovim" sudo make install || exit 1
  ) || return 1

  core::summary "    ✓ Neovim built from source (stable)"
}

# Install Neovim. Requires >= 0.8.0 for LazyVim.
# See: https://www.lazyvim.org/ — Requirements section.
_nvim::install_nvim() {
  local min_version="0.11.2"

  # Already installed — check version is sufficient.
  if core::check_installed nvim; then
    local current
    current="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    if core::version_ge "${current}" "${min_version}"; then
      core::log INFO "Neovim already installed: NVIM v${current}"
      core::summary "    ✓ NVIM v${current} already installed"
      return 0
    fi
    core::log WARN "Neovim ${current} too old (need >= ${min_version}), removing and reinstalling"
    core::pkg_remove neovim
    # Fall through to fresh install below
  fi

  # Ubuntu 22.04 ships neovim 0.6.1 which is too old for LazyVim (needs
  # >= 0.8.0). Check the repo version first; if insufficient, add the
  # neovim-ppa/unstable PPA which tracks latest stable releases (the name
  # "unstable" is misleading — it provides release builds, not nightly).
  # See: https://launchpad.net/~neovim-ppa/+archive/ubuntu/unstable
  # On Ubuntu 24.04+ the default repo version should be sufficient and
  # the PPA path will not be triggered.
  if [[ "${DOTFILES_PKG_MANAGER}" == "apt" ]]; then
    local pkg_version
    pkg_version="$(apt-cache show neovim 2>/dev/null | awk '/^Version:/{print $2; exit}')"

    local pkg_semver=""
    if [[ "${pkg_version}" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
      pkg_semver="${BASH_REMATCH[0]}"
    fi

    if [[ -z "${pkg_semver}" ]] || ! core::version_ge "${pkg_semver}" "${min_version}"; then
      core::run_cmd "Installing software-properties-common" sudo apt-get install -y software-properties-common || return 1
      core::run_cmd "Adding neovim PPA" sudo add-apt-repository -y ppa:neovim-ppa/unstable || return 1
    fi
  fi

  # CentOS/RHEL: repos ship very old neovim. Check version and fall back
  # to source build if insufficient (no PPA equivalent for dnf).
  if [[ "${DOTFILES_PKG_MANAGER}" == "dnf" ]]; then
    local pkg_version
    pkg_version="$(dnf info neovim 2>/dev/null | awk '/^Version/{print $NF; exit}')"

    local pkg_semver=""
    if [[ "${pkg_version}" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
      pkg_semver="${BASH_REMATCH[0]}"
    fi

    if [[ -z "${pkg_semver}" ]] || ! core::version_ge "${pkg_semver}" "${min_version}"; then
      core::log INFO "Repo neovim (${pkg_version:-not available}) < ${min_version}, building from source"
      _nvim::install_from_src || return 1
      return 0
    fi
  fi

  core::pkg_install neovim || return 1
}

# Clone or update the LazyVim config repo to ~/.config/nvim.
# Idempotent: if already cloned with correct remote, pulls latest.
# Otherwise backs up existing dirs (timestamped) and clones fresh.
_nvim::clone_config() {
  local repo="https://github.com/yangxingwu/neovim-lua-config.git"
  local nvim_dir="${HOME}/.config/nvim"

  # Already cloned with correct remote — pull latest (idempotent).
  if [[ -d "${nvim_dir}/.git" ]]; then
    local current_remote repo_path
    current_remote="$(git -C "${nvim_dir}" remote get-url origin 2>/dev/null)"
    repo_path="${repo#*github.com/}"
    if [[ "${current_remote}" == *"${repo_path}"* ]]; then
      core::run_cmd "Updating neovim config" git -C "${nvim_dir}" pull --quiet || return 1
      core::summary "    ✓ config updated: ~/.config/nvim"
      return 0
    fi
  fi

  # Back up existing nvim directories (timestamped, never overwrites previous backups).
  # All four directories form a set — restore them together using the same timestamp.
  # To restore:
  #   rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
  #   mv ~/.config/nvim.bak.<timestamp> ~/.config/nvim
  #   mv ~/.local/share/nvim.bak.<timestamp> ~/.local/share/nvim
  #   mv ~/.local/state/nvim.bak.<timestamp> ~/.local/state/nvim
  #   mv ~/.cache/nvim.bak.<timestamp> ~/.cache/nvim
  core::backup "${HOME}/.config/nvim"
  core::backup "${HOME}/.local/share/nvim"
  core::backup "${HOME}/.local/state/nvim"
  core::backup "${HOME}/.cache/nvim"

  core::run_cmd "Cloning neovim config" git clone "${repo}" "${nvim_dir}" || return 1
  core::summary "    ✓ config → ~/.config/nvim (cloned)"
}

# Pre-install plugins and treesitter parsers in headless mode.
# This makes the first interactive nvim launch fast (no waiting for downloads).
_nvim::headless_init() {
  # Restore plugins to exact versions pinned in lazy-lock.json (committed to repo).
  # The "!" makes Lazy wait until restore completes before proceeding.
  # See: https://lazy.folke.io/usage
  #
  # Retry logic: Lazy! restore exits 0 even when plugins fail to clone (network
  # issues). We verify that every plugin is installed and retry up to 3 times.
  for i in {1..3}; do
    core::run_cmd "Restoring Lazy plugins" nvim --headless "+Lazy! restore" +qa
    if nvim --headless \
      +'lua for _, p in pairs(require("lazy.core.config").plugins) do if not p._.installed then vim.cmd("cquit 1") end end' \
      +qa >/dev/null 2>&1; then
      break
    fi
    if [[ "${i}" -eq 3 ]]; then
      core::log ERROR "Lazy restore failed after 3 attempts"
      return 1
    fi
    core::log WARN "Lazy restore incomplete (attempt ${i}/3), retrying..."
    sleep 3
  done

  # Compile treesitter parsers declared in ensure_installed.
  # See: https://github.com/nvim-treesitter/nvim-treesitter#commands
  core::run_cmd "Compiling treesitter parsers" nvim --headless "+TSUpdate" +qa || return 1

  # NOTE: Mason LSP servers are NOT installed here.
  # LazyVim uses mason-lspconfig which triggers async installation during normal
  # nvim startup (in the config function via pkg:install()). There is no official
  # synchronous headless command in the Mason/LazyVim ecosystem.
  # Mason auto-installs missing servers on first real nvim launch (~10-20s background).
  # This is acceptable because:
  #   - lazyvim.json (committed to nvim config repo) declares which extras are
  #     enabled, so mason-lspconfig knows what to install on first launch
  #   - Lazy! sync already downloaded mason-lspconfig itself
  #   - The user gets a fully functional editor immediately (LSP installs in background)
  core::summary "    ✓ plugins and treesitter parsers installed (headless)"
}

install() {
  _nvim::install_deps || return 1
  _nvim::install_nvim || return 1
  _nvim::clone_config || return 1
  _nvim::headless_init || return 1
}

uninstall() {
  rm -rf "${HOME}/.config/nvim"
  core::summary "    ✓ removed ~/.config/nvim"

  # Neovim compiled from source: run make uninstall from the build dir.
  local nvim_src="${_NVIM_SRC_DIR}/neovim"
  if [[ -f "${nvim_src}/build/Makefile" ]]; then
    (
      cd "${nvim_src}/build"
      sudo make uninstall >/dev/null 2>&1 || true
    )
    core::summary "    ✓ removed neovim from /usr/local (source build)"
  fi
  rm -rf "${nvim_src}"

  # Remove luarocks compiled from source (make uninstall also removes its
  # module search paths: /usr/local/share/lua/5.1, /usr/local/lib/lua/5.1).
  local luarocks_src="${_NVIM_SRC_DIR}/luarocks-${_NVIM_LUAROCKS_VERSION}"
  if [[ -f "${luarocks_src}/Makefile" ]]; then
    pushd "${luarocks_src}" >/dev/null
    sudo make uninstall >/dev/null 2>&1 || true
    popd >/dev/null
    core::summary "    ✓ removed luarocks from /usr/local"
  fi

  # lua 5.1: no make uninstall target; remove known installed files.
  if [[ -f /usr/local/bin/lua ]] && lua -v 2>&1 | grep -q "Lua 5.1"; then
    sudo rm -f /usr/local/bin/lua /usr/local/bin/luac
    sudo rm -f /usr/local/lib/liblua.a
    sudo rm -f /usr/local/include/lua.h /usr/local/include/luaconf.h \
      /usr/local/include/lualib.h /usr/local/include/lauxlib.h /usr/local/include/lua.hpp
    sudo rm -f /usr/local/man/man1/lua.1 /usr/local/man/man1/luac.1
    core::summary "    ✓ removed Lua 5.1 from /usr/local"
  fi

  # Remove source directories (only ours).
  rm -rf "${_NVIM_SRC_DIR}/lua-${_NVIM_LUA_VERSION}"
  rm -rf "${_NVIM_SRC_DIR}/luarocks-${_NVIM_LUAROCKS_VERSION}"
}
