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
- **brew / apt / dnf**: available in default repositories on all platforms.
  `core::pkg_install sshpass` — no special handling needed.

**gh (GitHub CLI):**
- **brew (macOS)**: available in default formulae. `core::pkg_install gh`.
- **apt (Debian/Ubuntu)**: add the official GitHub CLI APT repository first
  (keyring to `/etc/apt/keyrings/`, source list via `wget`), then
  `core::pkg_install gh`. Follows official docs at
  https://github.com/cli/cli/blob/trunk/docs/install_linux.md.
- **dnf (Fedora)**: add the gh-cli repo via `dnf config-manager addrepo`,
  then `core::pkg_install gh`. Follows official docs.

In all cases the actual install goes through `core::pkg_install` — the
only platform-specific bit is the one-time repo/keyring setup on apt/dnf.

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

- Available in default repositories on all supported platforms (homebrew-core,
  apt, dnf). No tap or special repository needed.

## gh (GitHub CLI) Installation — Platform Detail

- **brew (macOS)**: `core::pkg_install gh` — available in homebrew-core.
- **apt (Debian/Ubuntu)**: add keyring to `/etc/apt/keyrings/` and source list
  via `wget`, then `core::pkg_install gh`. Per official docs:
  https://github.com/cli/cli/blob/trunk/docs/install_linux.md
- **dnf (Fedora)**: `dnf config-manager addrepo` with the official repo file,
  then `core::pkg_install gh`. Per official docs:
  https://github.com/cli/cli/blob/trunk/docs/install_linux.md

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
