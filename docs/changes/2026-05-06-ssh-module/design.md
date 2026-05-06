# SSH Module Design

Date: 2026-05-06

## Goal

Add a `modules/ssh.sh` module that configures SSH client settings, manages the
ssh() password wrapper, generates an ed25519 key pair on fresh machines, and
pushes the public key to GitHub.

## Module Metadata

```bash
MODULE_NAME="ssh"
MODULE_DESC="SSH client configuration and key management"
MODULE_PLATFORM="all"
```

## Position in Module List

After `git`, before `rust`. Rationale: logically "identity first, then
connectivity tools." No hard technical dependency on git module output.

## install() Steps

### 1. Install Packages

**sshpass:**
- **brew (macOS)**: not in default formulae; add the tap first
  (`brew tap esolitos/ipa`), then `core::pkg_install sshpass` works normally.
- **apt / dnf (Linux)**: `core::pkg_install sshpass` — available in default
  repositories.

In both cases the actual install goes through `core::pkg_install sshpass` —
the only platform-specific bit is the one-time tap on macOS.

**gh (GitHub CLI):**
- **brew / dnf**: available in default repositories, no special handling.
- **apt (Debian/Ubuntu)**: add the official GitHub CLI APT repository first
  (GPG key + source list), then `core::pkg_install gh` works normally.

In both cases the actual install goes through `core::pkg_install gh` — the
only platform-specific bit is the one-time repo setup on apt.

### 2. Create Directory Structure

```bash
~/.ssh              (mode 700)
~/.ssh/passwords    (mode 700)
~/.ssh/sockets      (mode 700)
```

Use `mkdir -p` + `chmod 700`. Idempotent by nature.

### 3. Write ~/.ssh/config (Only if File Does Not Exist)

```
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 10m
    IdentityFile ~/.ssh/id_ed25519
```

Strategy: **write-once, never overwrite**. If `~/.ssh/config` already exists,
skip this step entirely. This protects user-defined Host aliases added after
first install.

### 4. Generate ed25519 Key Pair (Only if Not Present)

```bash
ssh-keygen -t ed25519 -C "xingwu.yang@gmail.com" -f ~/.ssh/id_ed25519 -N ""
```

- `-N ""` — empty passphrase (user's stated preference).
- Skipped if `~/.ssh/id_ed25519` already exists (idempotent).

### 5. Push Public Key to GitHub

Flow:
1. Check `gh auth status`. If not authenticated:
   - Run `gh auth login` (interactive — user completes browser/token flow).
2. Check if the public key is already registered on GitHub:
   - `gh ssh-key list` and grep for the key fingerprint or content.
3. If not already registered:
   - `gh ssh-key add ~/.ssh/id_ed25519.pub --title "<hostname>"`
   - Title uses the machine's hostname for easy identification.

This step is interactive (gh auth login may require browser). Acceptable — same
pattern as `bootstrap::homebrew` which waits for user confirmation.

### 6. Write ssh() Wrapper

The wrapper function is stored as a standalone file:

```
~/.ssh/ssh-wrapper.sh
```

Content: the ssh() shell function that checks `~/.ssh/passwords/<hostname>` and
dispatches to `sshpass -f` or plain `ssh` accordingly.

The wrapper includes a header comment explaining the credential layout:
- **Username**: defined in `~/.ssh/config` via `User` directive per Host.
- **Password**: stored as plain text (one password per file, no other content)
  in `~/.ssh/passwords/<hostname>` with mode 600.

This separation follows SSH's standard config model — connection parameters in
config, secrets in dedicated files protected by filesystem permissions.

A managed block in `~/.zshrc` sources it:

```bash
# BEGIN dotfiles:ssh-wrapper
source "${HOME}/.ssh/ssh-wrapper.sh"
# END dotfiles:ssh-wrapper
```

This keeps `.zshrc` clean — only one source line instead of 30 lines of
function body.

## uninstall() Steps

1. Remove the `ssh-wrapper` managed block from `~/.zshrc`.
2. Remove `~/.ssh/ssh-wrapper.sh`.
3. **Do NOT delete**: `~/.ssh`, keys, config, passwords — these are user data.
4. **Do NOT uninstall**: sshpass, gh — other tools may depend on them.

## sshpass Availability Note

- **brew (macOS)**: requires `brew tap esolitos/ipa` before install. After the
  tap, `core::pkg_install sshpass` works like any other package.
- **apt / dnf (Linux)**: available in default repositories, no special handling.

## gh (GitHub CLI) Installation — apt Detail

Ubuntu/Debian does not ship `gh` in default repositories. The module adds the
official GitHub CLI repository before calling `core::pkg_install gh`:

```bash
# Add GitHub CLI GPG key and apt source (idempotent — skipped if already present)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt-get update
```

After the repo is added, `core::pkg_install gh` works like any other package.

## Security Considerations

- Private keys never enter the repository.
- `~/.ssh/passwords/` directory never enters the repository.
- `~/.ssh/config` (which may contain real hostnames/IPs) never enters the
  repository.
- Only the **generic wrapper function** and **default config template** are
  stored in the dotfiles repo — both contain no sensitive information.

## Testing

The integration test (`tests/test_install.sh`) should verify:
- `~/.ssh` directory exists with mode 700.
- `~/.ssh/sockets` directory exists with mode 700.
- `~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub` exist.
- `~/.ssh/config` exists and contains `Host *` with expected directives.
- `~/.ssh/ssh-wrapper.sh` exists.
- `.zshrc` contains the `ssh-wrapper` managed block.
- `sshpass` binary is on PATH.
- `gh` binary is on PATH.
- After uninstall: managed block removed from `.zshrc`, wrapper file removed,
  but `~/.ssh` directory and keys still present.

Note: GitHub public key push is **not tested** in CI (requires authentication).
The test verifies that `gh` is installed but skips the push step.
