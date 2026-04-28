# Add install/uninstall summary

## Context

After install.sh or uninstall.sh finishes, the user sees a stream of log lines
but no recap. Add a detailed summary table printed at the end showing what each
step actually did.

## Design

### API

core.sh provides two functions:

```bash
_CORE_SUMMARY=()

# core::summary <entry>
# Appends a line to the summary. Entries are printed verbatim by core::print_summary.
# Convention:
#   ""                     → blank line (section separator)
#   "  name"               → module/step header (2-space indent)
#   "    ✓ detail"         → action taken (4-space indent)
#   "    — reason"         → skipped (4-space indent)
core::summary() {
  _CORE_SUMMARY+=("${1}")
}

# core::print_summary
# Prints all recorded summary lines between box-drawing borders.
core::print_summary() { ... }
```

### Who calls core::summary

**bootstrap.sh** — each function appends its own result:
- `core::summary "  zsh                      ✓ already installed"`
- `core::summary "  Xcode Command Line Tools  ✓ installed"`

**core::run_module** — appends the module header on skip:
- `core::summary "  ghostty"` + `core::summary "    — skipped (mac only)"`

**modules/*.sh** — each install()/uninstall() appends its own detail lines:
- `core::summary "    ✓ config → ~/.gitconfig (user.name, user.email)"`
- `core::summary "    ✓ rustup already installed"`
- `core::summary "    ✓ plugins: zsh-autosuggestions, zsh-syntax-highlighting, ..."`

**install.sh / uninstall.sh** — calls core::print_summary at the end, and
inserts a separator (`core::summary ""`) between bootstrap and module sections.

### Output format

```
══════════════════════════════════════
  Summary
══════════════════════════════════════
  zsh                          ✓ already installed
  Xcode Command Line Tools     ✓ installed
  Homebrew                     ✓ already installed
  dev tools                    ✓ installed (cmake, meson, ninja, gettext)
──────────────────────────────────────
  git
    ✓ config → ~/.gitconfig (user.name, user.email)
  rust
    ✓ rustup already installed
    ✓ config → ~/.zprofile (cargo env)
  sheldon
    ✓ installed via cargo
    ✓ plugins: zsh-autosuggestions, zsh-syntax-highlighting,
      zsh-completions, fzf-tab, zsh-safe-rm, zsh-history-substring-search
    ✓ config → ~/.zshrc (sheldon source)
  ghostty
    — skipped (mac only)
  nvim
    ✓ neovim already installed: NVIM v0.10.4
    ✓ deps: ripgrep, fd, lazygit, node, shfmt, shellcheck
    ✓ cloned config → ~/.config/nvim
══════════════════════════════════════
```

### Files modified

- `lib/core.sh` — add `_CORE_SUMMARY`, `core::summary`, `core::print_summary`
- `lib/bootstrap.sh` — add `core::summary` calls at end of each function
- `lib/core.sh` core::run_module — add header + skip summary on platform mismatch
- `modules/git.sh` — add summary lines in install()/uninstall()
- `modules/rust.sh` — add summary lines
- `modules/fzf.sh` — add summary lines
- `modules/zoxide.sh` — add summary lines
- `modules/sheldon.sh` — add summary lines
- `modules/starship.sh` — add summary lines
- `modules/ghostty.sh` — add summary lines
- `modules/font-hack-nerd-font.sh` — add summary lines
- `modules/nvim.sh` — add summary lines
- `modules/tmux.sh` — add summary lines
- `install.sh` — add separator after bootstrap, call `core::print_summary`
- `uninstall.sh` — call `core::print_summary`

### Verification

Run `./install.sh` on macOS. Confirm:
1. Bootstrap section shows each step with ✓ and status
2. Separator line between bootstrap and modules
3. Each module shows header + detail lines
4. Platform-skipped modules show "— skipped (mac only)" or "(linux only)"
5. Already-installed tools show "already installed"
