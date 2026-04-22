# rust Module

**Date:** 2026-04-22
**Status:** Approved

## Purpose

Install the Rust toolchain via `rustup` so that `cargo` is available for tools that
have no package-manager equivalent (e.g. `tree-sitter-cli` used by the `nvim` module).

## Decision

Use the official `rustup` installer script on both macOS and Linux:

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
```

- `-y` — non-interactive
- `--no-modify-path` — `~/.cargo/env` is already present in the tracked
  `config/zsh/zshenv`, so rustup must not also append its own line and create a duplicate

`cargo` and `rustc` land in `~/.cargo/bin/`.

## Design

### Module interface

```bash
LINKS=()

pre_install()  # no-op — rustup has no pkg-manager prerequisites
install()      # rustup installer script
post_install() # source ~/.cargo/env for current session; log rustc version
```

### `install`: Idempotency

```bash
install() {
  if command -v rustup &>/dev/null; then
    core::log INFO "rustup already installed — skipping"
    return 0
  fi
  # run rustup installer
}
```

Re-running the module is safe: `rustup` is checked before the installer is fetched.

### `install`: Toolchain

Default toolchain installed by `rustup` is `stable`. No explicit toolchain pinning —
`stable` always tracks the latest stable release.

### `install`: DRY_RUN

```
[DRY-RUN] Would install rustup (stable toolchain)
```

### `post_install`: PATH — session and permanent

**Session:** after the rustup installer completes, `post_install` immediately sources:

```bash
source "${HOME}/.cargo/env"
```

This makes `cargo` available for the rest of the current install session (e.g. the
`nvim` module's `tree-sitter-cli` step) without needing a new shell.

**Permanent:** `. ~/.cargo/env` is already present in `config/zsh/zshenv`, which is
tracked by dotfiles and symlinked to `~/.zshenv` by the `zsh` module. No append step
needed here.

### Full module interface

```bash
MODULE_NAME="rust"
MODULE_DESC="Rust toolchain via rustup"
MODULE_PLATFORM="all"

LINKS=()

pre_install() { :; }

install() {
  # 1. Skip if rustup already installed
  # 2. Run rustup installer (-y --no-modify-path)
}

post_install() {
  # 1. source ~/.cargo/env  ← makes cargo available for rest of install session
  # 2. Log installed rustc version
}
```

## Module Ordering

`rust` must appear before `nvim` in `install.sh`'s module load list so that `cargo`
is available when `nvim`'s `pre_install` runs `cargo install --locked tree-sitter-cli`.

## What is Out of Scope

- Managing multiple Rust toolchain versions (nightly, beta) — not needed
- Installing project-specific toolchains via `rust-toolchain.toml` — handled per-project
- Updating Rust (`rustup update`) — not done on every install run
