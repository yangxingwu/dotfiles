# Module: ssh

SSH client configuration, key management, and transparent password-based login via sshpass.

## Module hooks

| Hook | Action |
|---|---|
| `install` | install sshpass + gh; create ~/.ssh dirs; write default config; generate ed25519 key; push pubkey to GitHub; install ssh() wrapper |
| `uninstall` | remove ssh-wrapper block from ~/.zshrc; remove ~/.config/dotfiles/ssh-wrapper.sh; retain keys, config, passwords |

## What it manages

- **Packages**: `sshpass`, `gh` (GitHub CLI)
- **Directories**: `~/.ssh` (700), `~/.ssh/passwords` (700), `~/.ssh/sockets` (700)
- **Config**: `~/.ssh/config` — Host * defaults (managed, overwritten each run to keep config in sync)
- **Key**: `~/.ssh/id_ed25519` — generated if absent, no passphrase
- **GitHub**: pushes public key via `gh ssh-key add` (interactive auth if needed)
- **Wrapper**: `~/.config/dotfiles/ssh-wrapper.sh` sourced from ~/.zshrc managed block

## SSH config defaults

```
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 10m
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

## Password-based login

The ssh() wrapper checks `~/.ssh/passwords/<hostname>` on each connection.
If a password file exists, it uses `sshpass -f` transparently. Otherwise,
plain ssh runs as normal.

Credential layout:
- **Username**: defined in `~/.ssh/config` via `User` directive per Host.
- **Password**: one password per file (plain text, mode 600) in `~/.ssh/passwords/<hostname>`.

## Platform notes

- **sshpass**: available in homebrew-core, apt, and dnf default repos.
- **gh (apt)**: requires adding official GitHub CLI APT repository first.
- **gh (dnf)**: requires adding gh-cli repo; detects dnf5 vs dnf4 automatically.
- **gh (brew)**: available in default formulae.
