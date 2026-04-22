# refactor: replace DEPS_MAC/DEPS_LINUX with pre_install/install/post_install hooks

Date: 2026-04-22
Type: refactor
Files: lib/core.sh, install.sh, uninstall.sh, modules/git.sh, modules/tmux.sh, modules/ghostty.sh, modules/rust.sh, modules/zsh.sh, modules/nvim.sh, config/zsh/zshenv, config/zsh/zshrc.mac, config/zsh/zshrc.linux, .claude/commands/new-module.md

## Background

The old module interface used `DEPS_MAC` and `DEPS_LINUX` arrays that were
processed by a generic install loop in `install.sh`. This gave modules no way to
express dependency ordering, run custom install logic, or distinguish between
"install a dependency" and "install the thing itself".

## What changed

- `core::pkg_install` extended to accept multiple packages (variadic); loops
  with `continue` in DRY_RUN so all packages are logged even in dry-run mode
- `install.sh` execution order changed to `pre_install → install → LINKS →
  post_install`; DEPS install loop removed; explicit `_MODULES` array replaces
  alphabetical glob so `rust` can be ordered before `nvim`
- `uninstall.sh` state-reset block updated: `DEPS_MAC`/`DEPS_LINUX` removed,
  `install() { :; }` default added
- `modules/git.sh`, `tmux.sh`, `ghostty.sh` migrated from `DEPS_*` to `install()`
- `modules/rust.sh` added: installs rustup stable toolchain via
  `--no-modify-path`; sources `~/.cargo/env` in `post_install` for the current
  session
- `modules/zsh.sh` rewritten: tracks `~/.zshenv` and platform-split `~/.zshrc`
  via symlinks; `pre_install` backs up existing `~/.zshenv` before the LINKS
  phase runs; `install()` installs sheldon + starship (+ zsh on Linux)
- `config/zsh/zshenv`, `zshrc.mac`, `zshrc.linux` added as tracked config files;
  all three source a `.local` escape hatch file for machine-specific content
- `modules/nvim.sh` rewritten: `pre_install` installs all LazyVim runtime deps
  (ripgrep, fd, lazygit, node, shfmt, shellcheck, tree-sitter-cli via cargo);
  `install` checks neovim version and prompts pkg-manager vs source build if
  below 0.9; `post_install` idempotently clones config repo to `~/.config/nvim`
- `/new-module` scaffold updated to emit the three-hook interface; `DEPS_*`
  removed from template and instructions

## Why

The three-hook interface makes dependency ordering explicit (rust before nvim),
lets modules run arbitrary install logic (rustup script, neovim source build),
and aligns the interface contract with what modules actually need to express.
The old `DEPS_*` arrays only supported package-manager installs and had no
mechanism for ordering or custom logic.
