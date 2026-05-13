# Bootstrap Refactor

## Problem

install.sh runs bootstrap (zsh, Xcode CLT, Homebrew, dev tools) on every
invocation. This adds 3+ seconds of overhead and noisy output even when using
`--only git`. The bootstrap steps are environment preparation that only needs
to happen once on a new machine — they don't belong in the module-install loop.

## Design

### Separation of Concerns

| Script | Role | When to run |
|--------|------|-------------|
| `bootstrap-macos.sh` | One-time macOS environment preparation | New machine, or after env breakage |
| `bootstrap-linux.sh` | One-time Linux environment preparation | Same |
| `install.sh` | Module installation only | Anytime, safe to repeat |

### bootstrap-macos.sh (rewrite existing)

Responsibilities:
1. Install Xcode Command Line Tools (if absent)
2. Install Homebrew (if absent)
3. Install modern bash via brew (if system bash < 4.3)
4. Verify zsh exists (macOS ships it since Catalina)
5. Set login shell to zsh (if not already)
6. Install dev tools: cmake, meson, ninja, gettext
7. Touch skeleton files: ~/.zshrc, ~/.zprofile, ~/.zshenv

Properties:
- Written in bash 3.2 compatible syntax (runs under system bash)
- Idempotent (safe to run multiple times)
- Ends with: "Bootstrap complete. Run ./install.sh to continue."

### bootstrap-linux.sh (new)

Responsibilities:
1. Install zsh (apt/dnf)
2. Set login shell to zsh
3. Install dev tools: git, curl, cmake, meson, ninja-build, gettext,
   pkg-config, libssl-dev/openssl-devel, libclang-dev/clang-devel,
   build-essential / @development-tools
4. Touch skeleton files: ~/.zshrc, ~/.zprofile, ~/.zshenv

Properties:
- Same as macOS: bash 3.2 compat (though Linux bash is modern, consistency)
- Idempotent
- Supports both apt (Debian/Ubuntu) and dnf (Fedora/RHEL)

### install.sh Changes

**Remove:**
- All bootstrap calls (bootstrap::zsh, bootstrap::xcode_clt,
  bootstrap::homebrew, bootstrap::dev_tools)
- `source lib/bootstrap.sh`

**No prerequisite checks in install.sh.** If bootstrap was not run,
detect::pkg_manager or the first module will fail naturally with clear errors.

**Bootstrap hint:** At the top of main(), print a one-line platform-specific
reminder so users know what to run if things fail:

```bash
case "${DOTFILES_OS}" in
mac) core::log INFO "Prerequisites: run ./bootstrap-macos.sh on a fresh machine" ;;
linux) core::log INFO "Prerequisites: run ./bootstrap-linux.sh on a fresh machine" ;;
esac
```

**Resulting main():**

```bash
main() {
  core::init
  core::parse_args "$@"
  detect::os

  case "${DOTFILES_OS}" in
  mac) core::log INFO "Prerequisites: run ./bootstrap-macos.sh on a fresh machine" ;;
  linux) core::log INFO "Prerequisites: run ./bootstrap-linux.sh on a fresh machine" ;;
  esac

  detect::pkg_manager

  local total=${#DOTFILES_SELECTED_MODULES[@]} i=0 name
  for name in "${DOTFILES_SELECTED_MODULES[@]}"; do
    i=$((i + 1))
    core::run_module install "${name}" "${i}" "${total}"
  done

  core::print_final_summary
}
```

### New Module: modules/homebrew.sh

Manages the Homebrew .zprofile shellenv block (macOS only). Replaces the
block-writing logic that was in bootstrap::homebrew.

```
MODULE_NAME="homebrew"
MODULE_DESC="Homebrew shell environment"
MODULE_PLATFORM="mac"
```

- `install()`: Detect brew prefix (Apple Silicon vs Intel), write managed block
  `eval "$(<prefix>/bin/brew shellenv)"` to .zprofile, eval shellenv for
  current session.
- `uninstall()`: Remove managed block from .zprofile.

Position in module list: first (before all other mac modules, since they
need brew on PATH for core::pkg_install to work).

### Delete: lib/bootstrap.sh

All logic moves to bootstrap-*.sh scripts. File removed entirely.

### CI Changes

`.github/workflows/test.yml`:

- macOS job: run `./bootstrap-macos.sh` before `bash tests/test_install.sh`
- Ubuntu/Fedora Docker: run `./bootstrap-linux.sh` in Dockerfile (or as
  test preamble) before install.sh

### Module List Update

```bash
DOTFILES_MODULES=(
  homebrew           # mac only: .zprofile shellenv (must be first)
  font-hack-nerd-font
  git
  ssh
  rust
  golang
  fzf
  zoxide
  sheldon
  atuin
  starship
  ghostty
  nvim
  tmux
)
```

### Migration Path

The refactor is backward-compatible in the following sense:
- Users who already ran install.sh have a working environment. Running the
  new install.sh will skip installing homebrew (already on PATH) but ensure
  the .zprofile block exists.
- New users must run bootstrap-*.sh first, then install.sh. README documents
  this two-step workflow.
