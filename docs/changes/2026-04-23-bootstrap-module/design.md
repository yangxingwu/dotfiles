# Bootstrap Module — Install Platform Prerequisites Before Modules Run

Date: 2026-04-23
Type: feature

## Summary

Add `lib/bootstrap.sh`, a new library providing platform-prerequisite
primitives. Together with restructured library-loading in `install.sh`, it
lets a fresh macOS or Linux machine run `./install.sh` from zero: the
installer itself ensures Homebrew (macOS), the Xcode Command Line Tools
(macOS), and base development tools (zsh + git + curl + a compiler toolchain
on Linux) are present before any module runs.

The existing `lib/core.sh` and module interface are untouched. `lib/detect.sh`
is restructured to remove its auto-run side effects — all library files now
source as pure function libraries, with `install.sh` explicitly orchestrating
the call sequence.

## Motivation

Today, `./install.sh` on a brand-new machine fails for a simple reason: its
first module (`git`, `nvim`, etc.) calls `core::pkg_install`, which dispatches
by `DOTFILES_PKG_MANAGER`. On a fresh macOS that variable resolves to
`"unknown"` because Homebrew isn't installed yet. The installer logs `WARN`
and skips every package, leaving the machine half-configured.

The README papers over this by requiring git and curl as prerequisites, but
it doesn't tell a macOS user to install Homebrew first, and it doesn't help
Linux users who start from a minimal image lacking git or a compiler
toolchain. The `dotfiles` project pitches itself as a "full auto-installer,"
so relying on hand-run prerequisite steps contradicts the advertised promise.

A secondary problem: `lib/detect.sh` ends with two lines that auto-run
`detect::os` and `detect::pkg_manager` when the file is sourced. This forces
a specific call order on every consumer and leaves no room to run work
*between* those two detections — which is exactly what a bootstrap step
needs (detect OS → install pkg manager → re-detect pkg manager). The
auto-run is convenient for today's orchestrator but prevents the next step.

## Design

### 1. File inventory

| File | Change |
|---|---|
| `lib/bootstrap.sh` | **New.** Two public primitives + two mac-specific helpers. |
| `lib/detect.sh` | **Modify.** Remove the two trailing auto-run lines; callers orchestrate. Also drop the `pacman` branch — Arch is not supported. |
| `lib/core.sh` | **Modify.** Drop the `pacman` branch from `core::pkg_install` — Arch is not supported. |
| `install.sh` | **Modify.** Source `bootstrap.sh`; in `main()`, organise work into three stages: ensure pkg manager (mac: CLT + brew via bootstrap; linux: no-op) → `detect::pkg_manager` → `bootstrap::dev_tools`. |
| `uninstall.sh` | **Modify.** Explicitly call `detect::os → detect::pkg_manager` (no bootstrap; uninstall does not install things). |
| `README.md` | **Modify.** Drop git/curl from Prerequisites; add a note that first run will install CLT / Homebrew / base tools and may prompt for sudo or a GUI confirmation. |
| `.claude/rules/shell-style.md` | **Modify.** Add `bootstrap::` to the namespace table. |
| `modules/*.sh` | **Unchanged.** |

### 2. `lib/bootstrap.sh` — public contract

Three public functions. The first two are macOS-specific (they only make
sense in that context); the third handles dev-tool installation for both
platforms.

```bash
# macOS: install the Xcode Command Line Tools (git, curl, clang, make, etc.).
# Idempotent.
bootstrap::xcode_clt()

# macOS: install Homebrew via its official installer. Idempotent. After
# install, eval brew shellenv so brew is on PATH for the rest of this run.
bootstrap::homebrew()

# Both platforms: install dev tools that modules assume exist — shell, vcs,
# downloader, compiler toolchain, build systems (cmake/meson/ninja/gettext).
# Bypasses core::pkg_install and calls native pm commands directly, because
# bootstrap already knows which pm to use and dnf requires groupinstall for
# "Development Tools" which core::pkg_install doesn't support.
bootstrap::dev_tools()
```

The two mac-specific functions aren't wrapped in a single `bootstrap::macos`
entry point because they're called in different slots in the orchestration
sequence: `xcode_clt` and `homebrew` run before `detect::pkg_manager`,
while `dev_tools` runs after (it needs `DOTFILES_PKG_MANAGER` set). See
Section 3.

### 3. Orchestration in `install.sh`

The library-source block at the top of the file adds one line
(`source lib/bootstrap.sh`). The detection/bootstrap calls go at the top
of `main()`, organised as three sequential stages:

```bash
# library sources (top of file, unchanged order aside from the new line)
source "${DOTFILES_ROOT}/lib/core.sh"
source "${DOTFILES_ROOT}/lib/detect.sh"
source "${DOTFILES_ROOT}/lib/bootstrap.sh"   # new

# ...

main() {
  detect::os

  # Stage A: ensure a pkg manager exists.
  # macOS requires CLT + Homebrew; Linux's apt/dnf ships with the distro.
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    bootstrap::xcode_clt
    bootstrap::homebrew
  fi

  # Stage B: identify the pkg manager.
  detect::pkg_manager

  # Stage C: install dev tools all modules assume exist.
  bootstrap::dev_tools

  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  # ... existing _MODULES loop, unchanged ...
}
```

The three stages read as a story: **ensure a pkg manager exists → identify
it → install dev tools**. Stage A is an `if` because only macOS has work
to do; Stages B and C are unconditional (both platforms need them).
`detect::pkg_manager` appears exactly once, between stages A and B.

`uninstall.sh` uses a shorter sequence — no bootstrap, because removing
dotfile symlinks never requires installing anything:

```bash
# top of file
source "${DOTFILES_ROOT}/lib/core.sh"
source "${DOTFILES_ROOT}/lib/detect.sh"

# ...

main() {
  detect::os
  detect::pkg_manager
  # ... existing _MODULES loop ...
}
```

### 4. macOS CLT installation

`xcode-select --install` pops a GUI dialog ("The software needs to be
installed. Would you like to install it now?") and returns control to the
shell immediately while the actual download runs in the background. Apple
provides no synchronous install API.

`bootstrap::xcode_clt` polls `xcode-select -p` in a `while` loop with:

- A 15-second interval between checks
- A 30-minute hard ceiling (errors out if exceeded — network failures, user
  cancelling the dialog, etc.)
- A progress log every iteration so the user knows why the installer is
  sitting idle

This polling approach is what every automation tool uses (Homebrew's own
installer, Ansible, Chef, nix-darwin). It's not pretty, but Apple's API
surface leaves no alternative.

### 5. macOS Homebrew installation

`bootstrap::homebrew` calls Homebrew's official upstream installer:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

The official installer is interactive by default ("Press RETURN to continue
or any other key to abort"). We do **not** set `NONINTERACTIVE=1` — the
brief confirmation lets the user review what brew is about to do before
granting sudo access.

After the installer completes, we run `brew shellenv` in the current shell
via `eval` so later modules in this install run can use `brew install`:

```bash
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
```

The two paths cover Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`).

**Persistent PATH setup** (so brew stays on PATH across future shell
sessions) is handled by the existing `zsh` module: `config/zsh/zshrc.mac`
already contains `eval "$(/opt/homebrew/bin/brew shellenv)"`, and the
zsh module's LINKS symlinks it into `~/.zshrc`. So the full chain is:
bootstrap `eval`s brew shellenv for the current install run; later in the
same run the zsh module's LINKS take effect; from then on every new shell
picks up brew via `~/.zshrc`.

A broader redesign where each module appends its own snippet into a real
(non-symlinked) `~/.zshrc` is a separate future effort — not relevant here.

### 6. `bootstrap::dev_tools` — what modules get

`bootstrap::dev_tools` runs on both platforms. Its job is to install every
dev tool that later modules assume exists. It calls native pm commands
directly (`brew install`, `sudo apt-get install`, etc.) rather than going
through `core::pkg_install` — bootstrap already knows the pm, and `dnf`
needs `groupinstall` for "Development Tools" which `core::pkg_install`
doesn't support.

**macOS** — CLT already provides `git`, `curl`, `gcc`/`clang`, `make`, and
macOS (Catalina+) ships with `zsh` as the default shell. The only missing
pieces are modern build systems:

```bash
brew install cmake meson ninja gettext
```

**Linux** — install everything needed, per pm. Both branches follow the
same shape: install the plain packages first, then add the compiler-
toolchain meta-package (`build-essential` on apt, `"Development Tools"`
group on dnf).

| Pkg manager | Plain packages | Compiler meta |
|---|---|---|
| apt | `zsh git curl cmake meson ninja-build gettext` | `build-essential` |
| dnf | `zsh git curl cmake meson ninja-build gettext` | `groupinstall "Development Tools"` |

```bash
case "${DOTFILES_PKG_MANAGER}" in
apt)
  sudo apt-get install -y zsh git curl cmake meson ninja-build gettext
  sudo apt-get install -y build-essential
  ;;
dnf)
  sudo dnf install -y zsh git curl cmake meson ninja-build gettext
  sudo dnf groupinstall -y "Development Tools"
  ;;
*)
  core::log ERROR "Unsupported Linux package manager: ${DOTFILES_PKG_MANAGER}"
  core::log ERROR "This installer supports apt (Debian/Ubuntu) and dnf (Fedora/RHEL) only."
  exit 1
  ;;
esac
```

The `*)` fallback is deliberate: when the user is on an unsupported Linux
pm, we want to fail loudly with actionable guidance rather than silently
skip (which would leave every subsequent module logging "Unknown package
manager — cannot install: <pkg>" with no explanation of why).

Notes on the package-name differences:

- **apt `ninja-build` vs brew `ninja`**: Debian packaging chose the
  longer name to avoid collision with other `ninja` binaries. Fedora/RHEL
  followed the Debian convention.
- **`build-essential` (Debian) vs `"Development Tools"` (Fedora/RHEL)**:
  meta/group that bundles `gcc`, `g++`, `make`, binutils, libc headers.
- **`gettext`**: needed by Neovim's source build for `.mo` message catalogues.

**pacman is not supported.** Arch Linux is out of scope for this project
— remove the `pacman` branch from `detect::pkg_manager` (in `lib/detect.sh`)
and `core::pkg_install` (in `lib/core.sh`) in this change too, so the code
doesn't advertise a pm it can't actually bootstrap.

`zsh` in this list creates a **temporary duplicate**: `modules/zsh.sh`
also installs `zsh` on Linux in its `install()`. The duplicate is harmless
because native pm commands short-circuit on already-installed packages,
but it should be cleaned up in a follow-up PR by removing `zsh` from the
module's Linux branch. (Out of scope here to keep the blast radius small.)

### 7. `lib/detect.sh` restructure

Remove these two trailing lines:

```bash
[[ -n "${DOTFILES_OS:-}" ]] || detect::os
[[ -n "${DOTFILES_PKG_MANAGER:-}" ]] || detect::pkg_manager
```

After the change, `lib/detect.sh` defines two pure functions and does
nothing else on source. Consumers (`install.sh`, `uninstall.sh`) decide
when to call them.

Also drop the `pacman` branch from `detect::pkg_manager`. Arch is not
supported — keeping a detection branch the installer can't follow through
on would be misleading.

Enhance the "unknown pm" warn message to name the supported set. Current:

```
warn: no supported package manager found
```

New:

```
warn: no supported package manager found on Linux (supported: apt, dnf)
```

The warn stays a warn (not an error) — `detect::pkg_manager` remains a pure
detection function. `bootstrap::dev_tools` is the one that hard-exits on
the same condition (see Section 6); escalating both to errors would be
redundant, and keeping detect as pure observation preserves the option to
call it from contexts where "unknown" is acceptable.

The file header already declares "Safe to source multiple times (idempotent
variable exports)." — which remains true, and now also "zero side effects
on source."

### 8. `lib/core.sh` — drop pacman

`core::pkg_install` currently has a `pacman` branch that mirrors
`detect::pkg_manager`. Remove it for the same reason: the installer can't
bootstrap Arch, so there's no need for downstream functions to support it.

### 9. README updates

**Prerequisites section** (current):
```
- bash 4+
- git
- curl
```

**Prerequisites section** (new):
```
- bash 4+
```

Plus a new paragraph under Quick Install:

> First run on a clean machine may take several minutes. On macOS, the
> installer triggers `xcode-select --install` (GUI confirmation required)
> and then Homebrew (sudo password required). On Linux, it installs zsh,
> git, curl and a compiler toolchain via your system's package manager
> (sudo required).

### 10. `.claude/rules/shell-style.md`

Add `bootstrap::` to the namespace table:

| File | Namespace | Examples |
|---|---|---|
| `lib/bootstrap.sh` | `bootstrap::` | `bootstrap::xcode_clt`, `bootstrap::homebrew`, `bootstrap::dev_tools` |

## Non-goals

- **No changes to the module interface or `_MODULES` list.** `brew` is not
  a module; it's infrastructure. Rust remains a module even though it has
  similar "infrastructure" properties — refactoring rust's placement is
  out of scope.
- **No new persistent brew-shellenv plumbing.** bootstrap only
  `eval`s brew shellenv for the current install run; persistence across
  future shells is handled by `config/zsh/zshrc.mac`'s existing
  `eval "$(brew shellenv)"` line (symlinked to `~/.zshrc` by the zsh
  module). No new file-writing logic in bootstrap itself.
- **No removal of duplicate zsh install** in `modules/zsh.sh`'s Linux
  branch. Harmless duplicate, cleaned up in a follow-up PR.
- **No linuxbrew support.** Linux uses the system package manager
  (apt/dnf). Users who want linuxbrew can still set
  `DOTFILES_PKG_MANAGER=brew` before running, but bootstrap does not
  install linuxbrew.
- **No changes to `core::pkg_install`.** It already handles the four
  package managers correctly; bootstrap relies on that existing dispatch.

## Risks and edge cases

1. **Xcode CLT download exceeds 30 minutes.** On slow networks this is
   plausible. `bootstrap::xcode_clt` errors out with a clear message;
   the user can re-run `./install.sh` once CLT finishes installing
   separately.

2. **User cancels the CLT GUI dialog.** `xcode-select -p` keeps returning
   non-zero, the poll loop hits the 30-minute ceiling, and the installer
   exits with an error. Acceptable failure mode — user sees what went wrong.

3. **User aborts Homebrew's RETURN prompt.** Official brew installer exits
   1, which propagates up through `set -e`. Clean failure.

4. **Sudo password times out mid-install.** brew's installer handles sudo;
   on Linux, `sudo apt-get install` etc. handle it. A password timeout
   fails `set -e`, user re-runs.

5. **Homebrew's install.sh URL or behavior changes.** `curl | bash` on a
   third-party script is a standing risk. Acceptable for a personal
   dotfiles installer; this is the recommended install path on brew.sh.

6. **`bootstrap::homebrew` doesn't find brew after installation.** Both
   the Apple Silicon path (`/opt/homebrew`) and the Intel path
   (`/usr/local`) are checked. If neither exists, `core::pkg_install` later
   will fail with "Unknown package manager" and skip with WARN — not great,
   but the CLT-and-brew install logs will have shown where things went
   wrong.

## Testing approach

No test harness in this project (out of scope). Verification is manual:

- `bash -n`, `shellcheck`, `shfmt -d` on all touched files
- Trial run: `./install.sh` on current macOS machine with brew already
  installed — verify everything is skipped with "Already installed" logs,
  no new behavior regressions
- `DOTFILES_OS=linux DOTFILES_PKG_MANAGER=apt` simulated source tests to
  verify the Stage C `bootstrap::dev_tools` branch dispatch
- Smoke test re-source safety: `source lib/bootstrap.sh` three times in
  the same shell under `set -euo pipefail`
- Actual clean-machine test (macOS VM or fresh user account) deferred —
  the user can verify manually after merge

## Open questions / future work

- **zsh-config redesign**: persistent `brew shellenv` in `~/.zprofile`,
  per-module `.zshrc` snippet composition, removal of direct symlink
  approach. Its own brainstorm and design doc.
- **Clean up `modules/zsh.sh`'s Linux branch**: remove the duplicate `zsh`
  package install now that bootstrap handles it.
- **Consider moving `rust.sh` to bootstrap** on the grounds that it's
  infrastructure (a dependency of nvim's tree-sitter-cli) rather than a
  user-facing module. Same logic as brew. Deferred — out of scope.
