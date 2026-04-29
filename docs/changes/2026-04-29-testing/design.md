# Testing Strategy: Integration Tests via GitHub Actions

## Context

The dotfiles project has zero tests. install.sh and uninstall.sh are the core
deliverables — they install packages, write config files, and modify shell init
files on real systems. Unit testing bash scripts with heavy side effects requires
excessive mocking. Integration testing on real environments is more valuable.

## Design

### Test approach

Run install.sh on a clean system, verify everything was set up correctly, then
run uninstall.sh and verify cleanup. No testing framework — plain bash with a
simple assert helper function.

### Test matrix (GitHub Actions)

| Job | Environment | Tests |
|---|---|---|
| macOS | `macos-latest` runner | All modules including mac-only (ghostty, font-hack-nerd-font) |
| Ubuntu | Docker `ubuntu:22.04` | All-platform modules, apt path |
| Fedora | Docker `fedora:latest` | All-platform modules, dnf path |

### Test script: `tests/test_install.sh`

One script, four phases:

1. **Install** — run `./install.sh` (pipe `echo "1"` for nvim interactive prompt)
2. **Verify install** — check binaries on PATH, config files exist with correct
   content, managed blocks present in ~/.zshrc and ~/.zprofile
3. **Uninstall** — run `./uninstall.sh`
4. **Verify uninstall** — check config files removed, managed blocks gone

Assert helper:

```bash
assert() {
  local desc="${1}"; shift
  if "$@"; then
    printf '  ✓ %s\n' "${desc}"
  else
    printf '  ✗ %s\n' "${desc}" >&2
    FAILURES=$((FAILURES + 1))
  fi
}
```

### What to verify

**Binaries** (after install):
- All platforms: git, zsh, nvim, tmux, fzf, zoxide, cargo, rustup, sheldon, starship
- macOS only: ghostty (via `brew list --cask ghostty`)

**Config files** (after install):
- `~/.gitconfig` contains `user.name` and `user.email`
- `~/.config/ghostty/config` contains `font-family` (macOS only)
- `~/.config/starship.toml` exists
- `~/.config/nvim/.git` exists (cloned repo)

**Shell init blocks** (after install):
- `~/.zshrc` contains `BEGIN dotfiles:fzf`, `BEGIN dotfiles:zoxide`,
  `BEGIN dotfiles:sheldon`, `BEGIN dotfiles:starship`
- `~/.zprofile` contains `BEGIN dotfiles:rust`, `BEGIN dotfiles:homebrew` (macOS)

**After uninstall**:
- Managed blocks removed from `~/.zshrc` and `~/.zprofile`
- `~/.config/ghostty/config` removed
- `~/.config/starship.toml` removed
- `~/.config/nvim` removed
- `~/.config/tmux/tmux.conf` unlinked
- Git config entries removed

### Dockerfiles

`tests/Dockerfile.ubuntu`:
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y sudo curl git
RUN useradd -m -s /bin/bash testuser && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER testuser
WORKDIR /home/testuser/dotfiles
COPY --chown=testuser:testuser . .
```

`tests/Dockerfile.fedora`:
```dockerfile
FROM fedora:latest
RUN dnf install -y sudo curl git
RUN useradd -m -s /bin/bash testuser && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER testuser
WORKDIR /home/testuser/dotfiles
COPY --chown=testuser:testuser . .
```

### GitHub Actions workflow: `.github/workflows/test.yml`

Three parallel jobs:
- `test-macos`: runs on `macos-latest`, executes `tests/test_install.sh` directly
- `test-ubuntu`: builds Docker image from `tests/Dockerfile.ubuntu`, runs test script
- `test-fedora`: builds Docker image from `tests/Dockerfile.fedora`, runs test script

Triggered on: push to main, pull requests.

Local development relies on `bash -n` + shellcheck for quick validation.
Integration tests run exclusively in CI to avoid polluting the developer's
environment.

### Files to create

- `tests/test_install.sh` — test script
- `tests/Dockerfile.ubuntu` — Ubuntu test container
- `tests/Dockerfile.fedora` — Fedora test container
- `.github/workflows/test.yml` — CI workflow
