#!/usr/bin/env bash
# tests/test_install.sh — Integration test for install.sh and uninstall.sh.
# Runs on a clean system (CI only — will modify the environment).
set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

# Create diagnostics directory early so it exists even if tests fail before Phase 2b.
mkdir -p /tmp/dotfiles-diagnostics
printf 'diagnostics will be written here if tests reach Phase 2b\n' >/tmp/dotfiles-diagnostics/README.txt

assert() {
  local desc="${1}"
  shift
  if "$@"; then
    printf '  ✓ %s\n' "${desc}"
  else
    printf '  ✗ %s\n' "${desc}"
    FAILURES=$((FAILURES + 1))
  fi
}

assert_file_exists() {
  assert "file exists: ${1}" test -f "${1}"
}

assert_file_missing() {
  assert "file missing: ${1}" test ! -f "${1}"
}

assert_dir_exists() {
  assert "dir exists: ${1}" test -d "${1}"
}

assert_dir_missing() {
  assert "dir missing: ${1}" test ! -d "${1}"
}

assert_command() {
  assert "command on PATH: ${1}" command -v "${1}"
}

assert_file_contains() {
  assert "file ${1} contains '${2}'" grep -q "${2}" "${1}"
}

assert_file_not_contains() {
  if grep -q "${2}" "${1}"; then
    printf '  ✗ file %s still contains %s\n' "${1}" "${2}"
    FAILURES=$((FAILURES + 1))
  else
    printf '  ✓ file %s missing %s\n' "${1}" "${2}"
  fi
}

detect_os() {
  case "$(uname -s)" in
  Darwin) printf 'mac' ;;
  Linux) printf 'linux' ;;
  esac
}

OS="$(detect_os)"

# Set git identity for non-interactive CI environment.
git config --global user.name "Test User"
git config --global user.email "test@example.com"

# ─── Phase 1: Install ──────────────────────────────────────────────
printf '\n══ Phase 1: Running install.sh ══\n'

"${DOTFILES_ROOT}/install.sh"

# install.sh runs as a child process, so PATH changes made by modules
# (e.g. rust sourcing ~/.cargo/env, golang exporting /usr/local/go/bin)
# only affect that subprocess. Source ~/.zprofile here to pick them up
# in the test process before Phase 2 checks for those binaries.
# shellcheck source=/dev/null
[[ -f "${HOME}/.zprofile" ]] && source "${HOME}/.zprofile"

# ─── Phase 1b: Idempotency — run install.sh a second time ─────────
printf '\n══ Phase 1b: Running install.sh again (idempotency check) ══\n'

"${DOTFILES_ROOT}/install.sh"

# If we got here without error, the second run didn't crash.
printf '  ✓ install.sh second run completed without error\n'

# Verify no duplicate managed blocks in .zshrc
for block_id in fzf zoxide sheldon atuin starship ssh lazygit; do
  count="$(grep -c "BEGIN dotfiles:${block_id}" "${HOME}/.zshrc" 2>/dev/null)" || count=0
  if [[ "${count}" -gt 1 ]]; then
    printf '  ✗ duplicate block: %s (count: %s)\n' "${block_id}" "${count}"
    FAILURES=$((FAILURES + 1))
  else
    printf '  ✓ no duplicate block: %s\n' "${block_id}"
  fi
done

# Verify no duplicate managed blocks in .zprofile
for block_id in rust golang homebrew python; do
  # homebrew block only exists on macOS
  if [[ "${block_id}" == "homebrew" && "${OS}" != "mac" ]]; then
    continue
  fi
  count="$(grep -c "BEGIN dotfiles:${block_id}" "${HOME}/.zprofile" 2>/dev/null)" || count=0
  if [[ "${count}" -gt 1 ]]; then
    printf '  ✗ duplicate block: %s (count: %s)\n' "${block_id}" "${count}"
    FAILURES=$((FAILURES + 1))
  else
    printf '  ✓ no duplicate block: %s\n' "${block_id}"
  fi
done

# ─── Phase 2: Verify install ───────────────────────────────────────
printf '\n══ Phase 2: Verifying install ══\n'

# Binaries (all platforms)
assert_command git
assert_command zsh
assert_command nvim
assert_command tmux
assert_command fzf
assert_dir_exists "${HOME}/.local/share/fzf/catppuccin"
assert_file_exists "${HOME}/.config/dotfiles/fzf.zsh"
assert_file_contains "${HOME}/.config/dotfiles/fzf.zsh" "FZF_DEFAULT_COMMAND"
assert_file_contains "${HOME}/.config/dotfiles/fzf.zsh" "catppuccin-fzf-mocha"
assert_command zoxide
assert_command cargo
assert_command rustup
assert_command sheldon
assert_command starship

# cli-tools
assert_command bat
assert_command eza
assert_command rg
assert_command fd
assert_command jq
assert_command tldr
assert_file_exists "${HOME}/.config/bat/config"
assert_file_contains "${HOME}/.config/bat/config" "Catppuccin Mocha"

# python module
assert_command python3
assert_command pip3
assert_command pipx
assert_file_contains "${HOME}/.zprofile" "BEGIN dotfiles:python"

# nodejs module
assert_command fnm
assert_command node
assert_command npm
assert_file_contains "${HOME}/.zprofile" "BEGIN dotfiles:nodejs"

# macOS-only binaries
if [[ "${OS}" == "mac" ]]; then
  assert "ghostty installed" brew list --cask ghostty
  assert "font-hack-nerd-font installed" brew list --cask font-hack-nerd-font
fi

# Git config
assert_file_contains "${HOME}/.gitconfig" "Test User"

# git module — tools and config
assert_command delta
assert_command lazygit
assert_file_exists "${HOME}/.config/lazygit/config.yml"
assert_file_contains "${HOME}/.config/lazygit/config.yml" "nerdFontsVersion"
assert_dir_exists "${HOME}/.local/share/lazygit/catppuccin"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:lazygit"
assert_file_exists "${HOME}/.config/git/ignore"
assert_file_contains "${HOME}/.config/git/ignore" ".DS_Store"
assert "git core.pager is delta" test "$(git config --global core.pager)" = "delta"
assert "git pull.rebase is true" test "$(git config --global pull.rebase)" = "true"
assert "git commit.gpgsign is true" test "$(git config --global commit.gpgsign)" = "true"
assert "git gpg.format is ssh" test "$(git config --global gpg.format)" = "ssh"

# SSH module
assert_dir_exists "${HOME}/.ssh"
assert "${HOME}/.ssh mode 700" test "$(stat -c '%a' "${HOME}/.ssh" 2>/dev/null || stat -f '%Lp' "${HOME}/.ssh")" = "700"
assert_dir_exists "${HOME}/.ssh/sockets"
assert_dir_exists "${HOME}/.ssh/passwords"
assert_file_exists "${HOME}/.ssh/id_ed25519"
assert_file_exists "${HOME}/.ssh/id_ed25519.pub"
assert_file_exists "${HOME}/.ssh/config"
assert_dir_exists "${HOME}/.ssh/config.d"
assert_file_exists "${HOME}/.ssh/config.d/dotfiles-defaults"
assert_file_contains "${HOME}/.ssh/config.d/dotfiles-defaults" "ServerAliveInterval 60"
assert_file_contains "${HOME}/.ssh/config.d/dotfiles-defaults" "ServerAliveCountMax 3"
assert_file_contains "${HOME}/.ssh/config.d/dotfiles-defaults" "Compression yes"
assert_file_contains "${HOME}/.ssh/config.d/dotfiles-defaults" "ControlMaster auto"
assert_file_contains "${HOME}/.ssh/config.d/dotfiles-defaults" "ControlPath ~/.ssh/sockets/%r@%h-%p"
assert_file_contains "${HOME}/.ssh/config.d/dotfiles-defaults" "ControlPersist 10m"
assert_file_contains "${HOME}/.ssh/config.d/dotfiles-defaults" "IdentityFile ~/.ssh/id_ed25519"
assert_file_contains "${HOME}/.ssh/config.d/dotfiles-defaults" "IdentitiesOnly yes"
assert_file_contains "${HOME}/.ssh/config" "Include config.d/dotfiles-defaults"
assert_file_exists "${HOME}/.config/dotfiles/ssh-wrapper.sh"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:ssh"
assert_command sshpass
assert_command gh

# Ghostty config (macOS only)
if [[ "${OS}" == "mac" ]]; then
  assert_file_exists "${HOME}/.config/ghostty/config"
  assert_file_contains "${HOME}/.config/ghostty/config" "Hack Nerd Font Mono"
fi

# Starship config
assert_file_exists "${HOME}/.config/starship.toml"

# Nvim config (cloned repo)
assert_dir_exists "${HOME}/.config/nvim/.git"

# nvim headless init
assert_dir_exists "${HOME}/.local/share/nvim/lazy"
assert_command luarocks

# tmux (oh-my-tmux)
assert_dir_exists "${HOME}/.local/share/tmux/oh-my-tmux"
assert "tmux.conf is a symlink" test -L "${HOME}/.config/tmux/tmux.conf"

# Module status file
assert_file_exists "${HOME}/.config/dotfiles/installed-modules"
assert_file_contains "${HOME}/.config/dotfiles/installed-modules" "rust"
assert_file_contains "${HOME}/.config/dotfiles/installed-modules" "nvim"
assert_file_contains "${HOME}/.config/dotfiles/installed-modules" "cli-tools"

# Shell init blocks in ~/.zshrc
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:fzf"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:zoxide"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:sheldon"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:atuin"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:starship"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:zsh-config"

# zsh-config
assert_file_contains "${HOME}/.zshrc" 'EDITOR="nvim"'
assert_file_contains "${HOME}/.zshrc" "setopt share_history"

# Atuin
assert_command atuin
assert_file_exists "${HOME}/.config/atuin/config.toml"
assert_file_contains "${HOME}/.config/atuin/config.toml" "auto_sync = false"

# Shell init blocks in ~/.zprofile
assert_file_contains "${HOME}/.zprofile" "BEGIN dotfiles:rust"
if [[ "${OS}" == "mac" ]]; then
  assert_file_contains "${HOME}/.zprofile" "BEGIN dotfiles:homebrew"
fi

# ─── Phase 2b: Diagnostic dumps (uploaded as CI artifacts) ─────────
printf '\n══ Phase 2b: Diagnostic dumps ══\n'

# nvim checkhealth — capture full output for review
nvim --headless -c "checkhealth" -c "w! /tmp/dotfiles-diagnostics/nvim-checkhealth.txt" -c "qa" 2>/dev/null || true
printf '  ✓ nvim checkhealth saved to /tmp/dotfiles-diagnostics/nvim-checkhealth.txt\n'

# ─── Phase 3: Uninstall ────────────────────────────────────────────
printf '\n══ Phase 3: Running uninstall.sh ══\n'

"${DOTFILES_ROOT}/uninstall.sh"

# ─── Phase 4: Verify uninstall ─────────────────────────────────────
printf '\n══ Phase 4: Verifying uninstall ══\n'

# Config files removed
if [[ "${OS}" == "mac" ]]; then
  assert_file_missing "${HOME}/.config/ghostty/config"
fi
assert_file_missing "${HOME}/.config/starship.toml"
assert_dir_missing "${HOME}/.config/nvim"

# tmux cleanup
assert_dir_missing "${HOME}/.local/share/tmux/oh-my-tmux"
assert "tmux.conf symlink removed" test ! -L "${HOME}/.config/tmux/tmux.conf"
assert_file_missing "${HOME}/.config/tmux/tmux.conf.local"

# Managed blocks removed from ~/.zshrc
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:fzf"
assert_dir_missing "${HOME}/.local/share/fzf/catppuccin"
assert_file_missing "${HOME}/.config/dotfiles/fzf.zsh"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:zoxide"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:sheldon"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:atuin"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:starship"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:zsh-config"

# Atuin uninstall
assert_file_missing "${HOME}/.config/atuin/config.toml"

# Managed blocks removed from ~/.zprofile
assert_file_not_contains "${HOME}/.zprofile" "BEGIN dotfiles:rust"
assert_file_not_contains "${HOME}/.zprofile" "BEGIN dotfiles:python"
if [[ "${OS}" == "mac" ]]; then
  assert_file_not_contains "${HOME}/.zprofile" "BEGIN dotfiles:homebrew"
fi

# Git config entries removed (identity preserved — user data)
assert_file_not_contains "${HOME}/.gitconfig" "defaultBranch"
assert_file_missing "${HOME}/.config/lazygit/config.yml"
assert_dir_missing "${HOME}/.local/share/lazygit/catppuccin"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:lazygit"
assert_file_missing "${HOME}/.config/git/ignore"
# git binaries retained
assert_command delta
assert_command lazygit

# cli-tools uninstall — config removed, binaries retained
assert_file_missing "${HOME}/.config/bat/config"
assert_command bat
assert_command eza
assert_command rg
assert_command fd
assert_command jq
assert_command tldr

# SSH module uninstall — wrapper removed, user data retained
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:ssh"
assert_file_missing "${HOME}/.config/dotfiles/ssh-wrapper.sh"
assert_file_missing "${HOME}/.ssh/config.d/dotfiles-defaults"
assert_file_not_contains "${HOME}/.ssh/config" "Include config.d/dotfiles-defaults"
assert_dir_exists "${HOME}/.ssh"
assert_file_exists "${HOME}/.ssh/id_ed25519"
assert_file_exists "${HOME}/.ssh/config"

# Module status cleared after uninstall
assert_file_not_contains "${HOME}/.config/dotfiles/installed-modules" "nvim"
assert_file_not_contains "${HOME}/.config/dotfiles/installed-modules" "rust"

# ─── Result ─────────────────────────────────────────────────────────
printf '\n══ Result ══\n'
if ((FAILURES > 0)); then
  printf '%d test(s) failed\n' "${FAILURES}"
  exit 1
else
  printf 'All tests passed\n'
fi
