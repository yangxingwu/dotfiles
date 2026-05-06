# SSH Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `modules/ssh.sh` that manages SSH client config, sshpass wrapper, ed25519 key generation, and GitHub public key deployment.

**Architecture:** Single module file following the existing module interface contract (MODULE_NAME/DESC/PLATFORM + install()/uninstall()). The ssh() wrapper function lives in a separate file (`~/.ssh/ssh-wrapper.sh`) sourced via a managed block in `.zshrc`. Platform-specific package source setup (brew tap for sshpass, apt repo for gh) happens before unified `core::pkg_install` calls.

**Tech Stack:** Bash, SSH, sshpass, gh (GitHub CLI)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `modules/ssh.sh` | Create | Module implementation: install/uninstall hooks |
| `lib/modules.sh` | Modify (line 10) | Add `ssh` to `DOTFILES_MODULES` after `git` |
| `tests/test_install.sh` | Modify | Add SSH verification assertions |

---

### Task 1: Create the SSH module file with metadata and skeleton

**Files:**
- Create: `modules/ssh.sh`

- [ ] **Step 1: Create `modules/ssh.sh` with module metadata and empty hooks**

```bash
#!/usr/bin/env bash
# modules/ssh.sh — SSH client configuration and key management
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="ssh"
MODULE_DESC="SSH client configuration and key management"
MODULE_PLATFORM="all"

install() {
  :
}

uninstall() {
  :
}
```

- [ ] **Step 2: Add `ssh` to the module list in `lib/modules.sh`**

In `lib/modules.sh`, add `ssh` after `git` and before `rust`:

```bash
DOTFILES_MODULES=(
  font-hack-nerd-font
  git
  ssh              # after git: identity before connectivity
  rust             # before nvim: cargo is required for tree-sitter-cli
  golang           # before nvim: go install lazygit
  fzf              # before zoxide: zi interactive mode uses fzf
                   # before sheldon: sheldon's fzf-tab plugin requires the fzf binary
  zoxide
  sheldon
  starship
  ghostty          # after font/sheldon/zoxide/starship: config assumes these are installed
  nvim             # after rust (cargo) and golang (go install lazygit)
  tmux
)
```

- [ ] **Step 3: Verify the module loads without error**

Run: `source lib/detect.sh && source lib/core.sh && source modules/ssh.sh && printf 'MODULE_NAME=%s\n' "${MODULE_NAME}"`

Expected output: `MODULE_NAME=ssh`

- [ ] **Step 4: Commit**

```bash
git add modules/ssh.sh lib/modules.sh
git commit -m "feat(ssh): add module skeleton with metadata"
```

---

### Task 2: Implement package installation (sshpass + gh)

**Files:**
- Modify: `modules/ssh.sh`

- [ ] **Step 1: Add helper function `_ssh::install_packages` to `modules/ssh.sh`**

Add above `install()`:

```bash
# Install sshpass and gh with platform-specific source setup.
_ssh::install_packages() {
  # sshpass: macOS needs a third-party tap
  if [[ "${DOTFILES_PKG_MANAGER}" == "brew" ]]; then
    if ! brew tap | grep -q "esolitos/ipa"; then
      brew tap esolitos/ipa
      core::log INFO "Added brew tap esolitos/ipa (for sshpass)"
    fi
  fi
  core::pkg_install sshpass

  # gh: Ubuntu/Debian needs the official GitHub CLI repository
  if [[ "${DOTFILES_PKG_MANAGER}" == "apt" ]]; then
    if [[ ! -f /etc/apt/sources.list.d/github-cli.list ]]; then
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
      sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
      printf 'deb [arch=%s signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' \
        "$(dpkg --print-architecture)" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update >/dev/null 2>&1
      core::log INFO "Added GitHub CLI APT repository"
    fi
  fi
  core::pkg_install gh
}
```

- [ ] **Step 2: Call `_ssh::install_packages` from `install()`**

Replace the `: ` placeholder in `install()`:

```bash
install() {
  _ssh::install_packages
}
```

- [ ] **Step 3: Commit**

```bash
git add modules/ssh.sh
git commit -m "feat(ssh): install sshpass and gh with platform-specific source setup"
```

---

### Task 3: Implement directory creation and SSH config writing

**Files:**
- Modify: `modules/ssh.sh`

- [ ] **Step 1: Add helper function `_ssh::setup_dirs_and_config`**

Add below `_ssh::install_packages`:

```bash
# Create ~/.ssh directory structure and write default config if absent.
_ssh::setup_dirs_and_config() {
  local ssh_dir="${HOME}/.ssh"

  mkdir -p "${ssh_dir}" "${ssh_dir}/passwords" "${ssh_dir}/sockets"
  chmod 700 "${ssh_dir}" "${ssh_dir}/passwords" "${ssh_dir}/sockets"
  core::log INFO "Ensured directory structure: ~/.ssh, ~/.ssh/passwords, ~/.ssh/sockets"
  core::summary "    ✓ directories: ~/.ssh, ~/.ssh/passwords, ~/.ssh/sockets (mode 700)"

  if [[ -f "${ssh_dir}/config" ]]; then
    core::log INFO "~/.ssh/config already exists — skipping (write-once policy)"
    core::summary "    ✓ ~/.ssh/config already exists (not overwritten)"
  else
    cat >"${ssh_dir}/config" <<'SSH_CONFIG'
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 10m
    IdentityFile ~/.ssh/id_ed25519
SSH_CONFIG
    chmod 600 "${ssh_dir}/config"
    core::log INFO "Wrote default ~/.ssh/config"
    core::summary "    ✓ wrote ~/.ssh/config (Host * defaults)"
  fi
}
```

- [ ] **Step 2: Call from `install()`**

```bash
install() {
  _ssh::install_packages
  _ssh::setup_dirs_and_config
}
```

- [ ] **Step 3: Commit**

```bash
git add modules/ssh.sh
git commit -m "feat(ssh): create directory structure and write default SSH config"
```

---

### Task 4: Implement ed25519 key generation

**Files:**
- Modify: `modules/ssh.sh`

- [ ] **Step 1: Add helper function `_ssh::generate_key`**

Add below `_ssh::setup_dirs_and_config`:

```bash
# Generate ed25519 key pair if not already present.
_ssh::generate_key() {
  local key_file="${HOME}/.ssh/id_ed25519"

  if [[ -f "${key_file}" ]]; then
    core::log INFO "SSH key already exists: ${key_file}"
    core::summary "    ✓ key already exists: ~/.ssh/id_ed25519"
  else
    ssh-keygen -t ed25519 -C "xingwu.yang@gmail.com" -f "${key_file}" -N ""
    core::log INFO "Generated SSH key: ${key_file}"
    core::summary "    ✓ generated key: ~/.ssh/id_ed25519"
  fi
}
```

- [ ] **Step 2: Call from `install()`**

```bash
install() {
  _ssh::install_packages
  _ssh::setup_dirs_and_config
  _ssh::generate_key
}
```

- [ ] **Step 3: Commit**

```bash
git add modules/ssh.sh
git commit -m "feat(ssh): generate ed25519 key pair on first install"
```

---

### Task 5: Implement GitHub public key push

**Files:**
- Modify: `modules/ssh.sh`

- [ ] **Step 1: Add helper function `_ssh::push_key_to_github`**

Add below `_ssh::generate_key`:

```bash
# Push public key to GitHub via gh CLI. Authenticates interactively if needed.
_ssh::push_key_to_github() {
  local pub_key="${HOME}/.ssh/id_ed25519.pub"
  local key_title
  key_title="$(hostname)"

  # Ensure gh is authenticated — run interactive login if not.
  if ! gh auth status >/dev/null 2>&1; then
    core::log INFO "gh not authenticated — starting interactive login"
    gh auth login
  fi

  # Check if this key is already registered on GitHub.
  local pub_content
  pub_content="$(cat "${pub_key}")"
  if gh ssh-key list | grep -qF "${pub_content##* }"; then
    core::log INFO "SSH key already registered on GitHub"
    core::summary "    ✓ public key already on GitHub"
  else
    gh ssh-key add "${pub_key}" --title "${key_title}"
    core::log INFO "Pushed SSH public key to GitHub (title: ${key_title})"
    core::summary "    ✓ public key pushed to GitHub (title: ${key_title})"
  fi
}
```

- [ ] **Step 2: Call from `install()`**

```bash
install() {
  _ssh::install_packages
  _ssh::setup_dirs_and_config
  _ssh::generate_key
  _ssh::push_key_to_github
}
```

- [ ] **Step 3: Commit**

```bash
git add modules/ssh.sh
git commit -m "feat(ssh): push public key to GitHub with interactive auth"
```

---

### Task 6: Implement ssh() wrapper file and zshrc block

**Files:**
- Modify: `modules/ssh.sh`

- [ ] **Step 1: Add helper function `_ssh::install_wrapper`**

Add below `_ssh::push_key_to_github`:

```bash
# Write the ssh() wrapper function to ~/.ssh/ssh-wrapper.sh and source it
# from .zshrc via a managed block.
_ssh::install_wrapper() {
  local wrapper_file="${HOME}/.ssh/ssh-wrapper.sh"

  cat >"${wrapper_file}" <<'WRAPPER'
# ssh-wrapper.sh — transparent password-based SSH via sshpass
#
# Credential layout:
#   - Username: defined in ~/.ssh/config via "User" directive per Host.
#   - Password: stored as plain text (one password per file, no other content)
#     in ~/.ssh/passwords/<hostname> with mode 600.
#
# If a password file exists for the target host, sshpass feeds it automatically.
# Otherwise, plain ssh runs as normal (key-based or interactive password prompt).

ssh() {
  local host

  # Use 'ssh -G' to have ssh itself parse all arguments and tell us the final hostname.
  # This avoids manually handling complex cases like -p, -vp, aliases, etc.
  # '2>/dev/null' suppresses errors when the command doesn't include a hostname (e.g., 'ssh -V').
  host=$(command ssh -G "$@" 2>/dev/null | awk '/^hostname / {print $2; exit}')

  # If 'ssh -G' successfully parsed a hostname...
  if [[ -n "${host}" ]]; then
    local password_file="${HOME}/.ssh/passwords/${host}"

    if [[ -f "${password_file}" ]]; then
      # Password file found — execute with sshpass.
      sshpass -f "${password_file}" command ssh "$@"
    else
      # No password file — execute normally (key-based auth).
      command ssh "$@"
    fi
  else
    # If 'ssh -G' couldn't resolve a hostname (e.g., for 'ssh -h' or 'ssh -V'),
    # fall back to the original ssh command.
    command ssh "$@"
  fi
}
WRAPPER
  chmod 644 "${wrapper_file}"
  core::log INFO "Wrote ssh wrapper to ~/.ssh/ssh-wrapper.sh"

  core::ensure_block "${HOME}/.zshrc" "ssh-wrapper" \
    "source \"\${HOME}/.ssh/ssh-wrapper.sh\""
  core::summary "    ✓ ssh-wrapper.sh → ~/.ssh/ssh-wrapper.sh"
  core::summary "    ✓ config → ~/.zshrc (source ssh-wrapper.sh)"
}
```

- [ ] **Step 2: Call from `install()`**

```bash
install() {
  _ssh::install_packages
  _ssh::setup_dirs_and_config
  _ssh::generate_key
  _ssh::push_key_to_github
  _ssh::install_wrapper
}
```

- [ ] **Step 3: Commit**

```bash
git add modules/ssh.sh
git commit -m "feat(ssh): add sshpass wrapper function sourced from .zshrc"
```

---

### Task 7: Implement uninstall()

**Files:**
- Modify: `modules/ssh.sh`

- [ ] **Step 1: Implement `uninstall()` in `modules/ssh.sh`**

Replace the placeholder:

```bash
uninstall() {
  core::remove_block "${HOME}/.zshrc" "ssh-wrapper"
  core::summary "    ✓ removed ssh-wrapper block from ~/.zshrc"

  rm -f "${HOME}/.ssh/ssh-wrapper.sh"
  core::summary "    ✓ removed ~/.ssh/ssh-wrapper.sh"

  # Intentionally NOT removed: ~/.ssh, keys, config, passwords (user data).
  core::summary "    — retained ~/.ssh (keys, config, passwords are user data)"
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/ssh.sh
git commit -m "feat(ssh): implement uninstall hook (clean wrapper, keep user data)"
```

---

### Task 8: Add SSH assertions to integration tests

**Files:**
- Modify: `tests/test_install.sh`

- [ ] **Step 1: Add install verification assertions after the existing "Git config" block (around line 99)**

Add after the `assert_file_contains "${HOME}/.gitconfig" "yangxingwu"` line:

```bash
# SSH module
assert_dir_exists "${HOME}/.ssh"
assert "~/.ssh mode 700" test "$(stat -c '%a' "${HOME}/.ssh" 2>/dev/null || stat -f '%Lp' "${HOME}/.ssh")" = "700"
assert_dir_exists "${HOME}/.ssh/sockets"
assert_dir_exists "${HOME}/.ssh/passwords"
assert_file_exists "${HOME}/.ssh/id_ed25519"
assert_file_exists "${HOME}/.ssh/id_ed25519.pub"
assert_file_exists "${HOME}/.ssh/config"
assert_file_contains "${HOME}/.ssh/config" "ServerAliveInterval 60"
assert_file_contains "${HOME}/.ssh/config" "ControlMaster auto"
assert_file_contains "${HOME}/.ssh/config" "ControlPersist 10m"
assert_file_exists "${HOME}/.ssh/ssh-wrapper.sh"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:ssh-wrapper"
assert_command sshpass
assert_command gh
```

- [ ] **Step 2: Add uninstall verification assertions (Phase 4, after "Git config entries removed")**

Add after the `assert_file_not_contains "${HOME}/.gitconfig" "yangxingwu"` line:

```bash
# SSH module uninstall — wrapper removed, user data retained
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:ssh-wrapper"
assert_file_missing "${HOME}/.ssh/ssh-wrapper.sh"
assert_dir_exists "${HOME}/.ssh"
assert_file_exists "${HOME}/.ssh/id_ed25519"
assert_file_exists "${HOME}/.ssh/config"
```

- [ ] **Step 3: Commit**

```bash
git add tests/test_install.sh
git commit -m "test(ssh): add install/uninstall assertions for SSH module"
```

---

### Task 9: Final review and cleanup

- [ ] **Step 1: Read the complete `modules/ssh.sh` and verify internal consistency**

Check that:
- All helper functions (`_ssh::install_packages`, `_ssh::setup_dirs_and_config`, `_ssh::generate_key`, `_ssh::push_key_to_github`, `_ssh::install_wrapper`) are called in order from `install()`.
- `uninstall()` reverses only what the module owns.
- No `readonly` declarations in the module file.
- All output goes through `core::log` (no raw printf/echo).
- All variables are quoted with braces.

- [ ] **Step 2: Run shellcheck**

Run: `shellcheck modules/ssh.sh`

Expected: No errors. Fix any warnings.

- [ ] **Step 3: Run shfmt**

Run: `shfmt -w modules/ssh.sh`

- [ ] **Step 4: Final commit if any formatting changes**

```bash
git add modules/ssh.sh
git commit -m "style(ssh): apply shfmt formatting"
```
