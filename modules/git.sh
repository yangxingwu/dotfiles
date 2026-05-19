#!/usr/bin/env bash
# modules/git.sh — Git configuration, tools, and workflow defaults
# Platform: all
#
# Configures:
#   - User identity (name, email)
#   - delta (syntax-highlighted diff pager) via cargo
#   - lazygit (git TUI) via go install
#   - SSH commit signing (reuses key from ssh module)
#   - Global gitignore (~/.config/git/ignore)
#   - Modern workflow defaults (rebase, autostash, histogram diff, etc.)
#   - lazygit catppuccin-mocha theme via --use-config-file merge
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="git"
MODULE_DESC="Git configuration, delta, lazygit, SSH signing"
MODULE_PLATFORM="all"
MODULE_DEPS=("ssh" "rust" "golang")

_GIT_GLOBAL_IGNORE="${HOME}/.config/git/ignore"
_GIT_LAZYGIT_CONFIG="${HOME}/.config/lazygit/config.yml"
_GIT_LAZYGIT_THEME_REPO="https://github.com/catppuccin/lazygit.git"
_GIT_LAZYGIT_THEME_DIR="${HOME}/.local/share/lazygit/catppuccin"
_GIT_LAZYGIT_THEME_FILE="${_GIT_LAZYGIT_THEME_DIR}/themes-mergable/mocha/blue.yml"

# Set git user identity.
# Configure git identity from existing config or interactive prompt.
# Priority: existing git config → interactive prompt → skip.
_git::configure_identity() {
  local name=""
  local email=""

  # Resolve name.
  name="$(git config --global user.name 2>/dev/null || true)"
  if [[ -n "${name}" ]]; then
    core::log INFO "Using existing git user.name: ${name}"
  else
    [[ ! -t 0 ]] && {
      core::log WARN "Git user.name not set — skipping"
      return 0
    }
    read -rp '  Git user.name not configured. Name: ' name
    git config --global user.name "${name}"
    core::log INFO "Configured git user.name: ${name}"
  fi

  # Resolve email.
  email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "${email}" ]]; then
    core::log INFO "Using existing git user.email: ${email}"
  else
    [[ ! -t 0 ]] && {
      core::log WARN "Git user.email not set — skipping"
      return 0
    }
    read -rp '  Git user.email not configured. Email: ' email
    git config --global user.email "${email}"
    core::log INFO "Configured git user.email: ${email}"
  fi

  core::summary "    ✓ identity: ${name} <${email}>"
}

# Install delta (diff pager) and lazygit (git TUI).
_git::install_tools() {
  if core::check_installed delta; then
    core::log INFO "Already installed: delta"
    core::summary "    ✓ delta already installed"
  else
    core::run_cmd "Installing git-delta" cargo install git-delta || return 1
    core::summary "    ✓ delta installed via cargo"
  fi

  if core::check_installed lazygit; then
    core::log INFO "Already installed: lazygit"
    core::summary "    ✓ lazygit already installed"
  else
    core::run_cmd "Installing lazygit" go install github.com/jesseduffield/lazygit@latest || return 1
    core::summary "    ✓ lazygit installed via go"
  fi
}

# Clone catppuccin theme repo, write lazygit config, and set up shell alias.
_git::configure_lazygit() {
  # Clone or update catppuccin/lazygit theme repository.
  if [[ -d "${_GIT_LAZYGIT_THEME_DIR}" ]]; then
    core::run_cmd "Updating lazygit catppuccin theme" git -C "${_GIT_LAZYGIT_THEME_DIR}" pull --quiet || return 1
  else
    mkdir -p "$(dirname "${_GIT_LAZYGIT_THEME_DIR}")"
    core::run_cmd "Cloning lazygit catppuccin theme" git clone --quiet "${_GIT_LAZYGIT_THEME_REPO}" "${_GIT_LAZYGIT_THEME_DIR}" || return 1
  fi
  core::summary "    ✓ catppuccin theme → ~/.local/share/lazygit/catppuccin"

  # Write minimal lazygit config (theme is merged via --use-config-file).
  mkdir -p "$(dirname "${_GIT_LAZYGIT_CONFIG}")"
  cat >"${_GIT_LAZYGIT_CONFIG}" <<'YAML'
gui:
  # Use Nerd Font v3 icons in lazygit UI (pairs with Hack Nerd Font installed by font module)
  nerdFontsVersion: "3"
YAML
  core::log INFO "Wrote lazygit config: ${_GIT_LAZYGIT_CONFIG}"
  core::summary "    ✓ config → ~/.config/lazygit/config.yml"

  # Shell alias to merge catppuccin theme at launch.
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "lazygit" \
    '# Merge catppuccin mocha theme at launch via --use-config-file.
# See: https://github.com/catppuccin/lazygit#usage
alias lazygit='\''lazygit --use-config-file="$HOME/.config/lazygit/config.yml,$HOME/.local/share/lazygit/catppuccin/themes-mergable/mocha/blue.yml"'\'''
  core::summary "    ✓ config → ~/.zshrc (lazygit alias with catppuccin theme)"
}

# Write global gitignore for common OS/editor artifacts.
_git::write_global_gitignore() {
  mkdir -p "$(dirname "${_GIT_GLOBAL_IGNORE}")"
  cat >"${_GIT_GLOBAL_IGNORE}" <<'GITIGNORE'
# Global gitignore — OS and editor artifacts only.
# Project-specific ignores (node_modules, .env, etc.) belong in each project's .gitignore.
#
# Sources:
#   https://github.com/github/gitignore/blob/main/Global/macOS.gitignore
#   https://github.com/github/gitignore/blob/main/Global/Linux.gitignore
#   https://github.com/github/gitignore/blob/main/Global/Vim.gitignore
#   https://github.com/github/gitignore/blob/main/Global/JetBrains.gitignore

# --- macOS ---
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes

# --- Linux ---
*~
.directory

# --- Vim / Neovim ---
*.swp
*.swo
[._]*.un~
Session.vim
Sessionx.vim
.netrwhist
tags

# --- JetBrains IDEs ---
.idea/

# --- Visual Studio Code ---
.vscode/
*.code-workspace
GITIGNORE
  core::log INFO "Wrote global gitignore: ${_GIT_GLOBAL_IGNORE}"
  core::summary "    ✓ config → ~/.config/git/ignore (global gitignore)"
}

# Configure modern git workflow defaults, delta integration, and SSH signing.
_git::configure_workflow() {
  # -- Workflow --
  # Default branch name for new repos
  git config --global init.defaultBranch main
  # Use rebase instead of merge on pull (linear history)
  git config --global pull.rebase true
  # Auto-stash before rebase, auto-pop after
  git config --global rebase.autoStash true
  # Auto-set upstream tracking branch on push (no more -u origin branch)
  git config --global push.autoSetupRemote true
  # Remember conflict resolutions and auto-apply next time
  git config --global rerere.enabled true
  # Use nvim as default editor for commit messages, rebase, etc.
  git config --global core.editor nvim

  # -- Diff --
  # Histogram diff algorithm (more readable output than default myers)
  git config --global diff.algorithm histogram
  # Color moved code blocks differently (distinguish moves from changes)
  git config --global diff.colorMoved default

  # -- Delta integration (official recommended config) --
  # See: https://dandavison.github.io/delta/get-started.html
  # Use delta as pager (syntax highlighting for diffs)
  git config --global core.pager delta
  # Use delta for interactive rebase coloring
  git config --global interactive.diffFilter "delta --color-only"
  # Enable n/N navigation between diff hunks in delta
  git config --global delta.navigate true
  # Tell delta we use a dark terminal background (affects syntax theme selection)
  git config --global delta.dark true

  # -- Version-gated features --
  local git_version
  git_version="$(git --version | awk '{print $3}')"

  # zdiff3 conflict style requires git >= 2.35.
  if core::version_ge "${git_version}" "2.35"; then
    git config --global merge.conflictstyle zdiff3
  else
    core::log WARN "Git ${git_version} < 2.35 — skipping merge.conflictstyle=zdiff3"
  fi

  # SSH commit signing requires git >= 2.34.
  if core::version_ge "${git_version}" "2.34"; then
    # Sign all commits and tags (GitHub shows Verified badge)
    git config --global commit.gpgsign true
    git config --global tag.gpgsign true
    # Use SSH key format instead of GPG
    git config --global gpg.format ssh
    # Use the ed25519 SSH key as signing key
    git config --global user.signingkey "${HOME}/.ssh/id_ed25519.pub"
    core::summary "    ✓ config → SSH commit signing (git ${git_version})"
  else
    core::log WARN "Git ${git_version} < 2.34 — skipping SSH signing config"
    core::summary "    — skipped SSH signing (git ${git_version} < 2.34)"
  fi

  # -- Global gitignore --
  # Shared ignore rules for OS/editor/language junk across all repos
  git config --global core.excludesFile "${_GIT_GLOBAL_IGNORE}"

  core::log INFO "Configured git workflow defaults"
  core::summary "    ✓ config → ~/.gitconfig (workflow, delta, signing, gitignore)"
}

# Push SSH public key to GitHub as a signing key (separate from authentication key).
# Skipped in non-interactive environments (no TTY) since auth flows require interaction.
# Requires the "admin:ssh_signing_key" OAuth scope on gh — requests it via
# gh auth refresh if not already granted.
_git::push_signing_key_to_github() {
  # Auth and scope refresh require interactive flows — skip entirely without TTY.
  if [[ ! -t 0 ]]; then
    core::log INFO "No TTY — skipping signing key push"
    core::summary "    — skipped signing key push (non-interactive)"
    return 0
  fi

  local pub_key="${HOME}/.ssh/id_ed25519.pub"
  local key_title
  key_title="$(awk '{print $3}' "${pub_key}")"

  # Check auth status and scope in one call.
  local auth_output
  auth_output="$(gh auth status 2>&1)" || {
    core::log INFO "gh not authenticated — starting interactive login"
    # --skip-ssh-key: key upload is handled by ssh module, not here.
    if ! gh auth login --skip-ssh-key; then
      core::log WARN "GitHub authentication failed — skipping signing key push"
      core::summary "    — skipped signing key push (auth failed)"
      return 0
    fi
    auth_output="$(gh auth status 2>&1)"
  }

  # Ensure gh has the admin:ssh_signing_key scope (required for signing key operations).
  if [[ "${auth_output}" != *"admin:ssh_signing_key"* ]]; then
    core::log INFO "Requesting admin:ssh_signing_key scope from GitHub"
    if ! gh auth refresh -h github.com -s admin:ssh_signing_key; then
      core::log ERROR "Failed to refresh gh scope for signing key"
      return 1
    fi
  fi

  # Check if this key is already registered as a signing key on GitHub.
  local key_body
  key_body="$(awk '{print $2}' "${pub_key}")"
  if gh ssh-key list 2>/dev/null | grep -F "${key_body}" | grep -q "signing"; then
    core::log INFO "SSH signing key already registered on GitHub"
    core::summary "    ✓ SSH signing key already on GitHub"
  else
    if gh ssh-key add "${pub_key}" --title "${key_title}" --type signing; then
      core::log INFO "Pushed SSH signing key to GitHub"
      core::summary "    ✓ SSH signing key pushed to GitHub"
    else
      core::log WARN "Failed to push SSH signing key to GitHub"
      core::summary "    — failed to push signing key (check gh auth scope)"
      return 1
    fi
  fi
}

install() {
  _git::configure_identity || return 1
  _git::install_tools || return 1
  _git::configure_lazygit || return 1
  _git::write_global_gitignore || return 1
  _git::configure_workflow || return 1
  _git::push_signing_key_to_github || return 1
}

uninstall() {
  # Identity — not removed (user data, not dotfiles-managed config)

  # Workflow
  git config --global --unset init.defaultBranch 2>/dev/null || true
  git config --global --unset pull.rebase 2>/dev/null || true
  git config --global --unset rebase.autoStash 2>/dev/null || true
  git config --global --unset push.autoSetupRemote 2>/dev/null || true
  git config --global --unset merge.conflictstyle 2>/dev/null || true
  git config --global --unset rerere.enabled 2>/dev/null || true
  git config --global --unset core.editor 2>/dev/null || true

  # Diff
  git config --global --unset diff.algorithm 2>/dev/null || true
  git config --global --unset diff.colorMoved 2>/dev/null || true

  # Delta
  git config --global --unset core.pager 2>/dev/null || true
  git config --global --unset interactive.diffFilter 2>/dev/null || true
  git config --global --remove-section delta 2>/dev/null || true

  # Signing
  git config --global --unset commit.gpgsign 2>/dev/null || true
  git config --global --unset tag.gpgsign 2>/dev/null || true
  git config --global --unset gpg.format 2>/dev/null || true
  git config --global --unset user.signingkey 2>/dev/null || true

  # Gitignore
  git config --global --unset core.excludesFile 2>/dev/null || true
  rm -f "${_GIT_GLOBAL_IGNORE}"

  # Lazygit config, theme, and alias
  rm -f "${_GIT_LAZYGIT_CONFIG}"
  rm -rf "${_GIT_LAZYGIT_THEME_DIR}"
  core::remove_block "${HOME}/.zshrc" "lazygit"

  core::log INFO "Removed git config, lazygit config/theme, global gitignore"
  core::summary "    ✓ removed git config entries"
  core::summary "    ✓ removed ~/.config/lazygit/config.yml"
  core::summary "    ✓ removed ~/.local/share/lazygit/catppuccin"
  core::summary "    ✓ removed lazygit alias from ~/.zshrc"
  core::summary "    ✓ removed ~/.config/git/ignore"

  # Binaries intentionally NOT removed: delta, lazygit
  core::log INFO "Retained binaries: delta, lazygit"
  core::summary "    — retained binaries: delta, lazygit"
}
