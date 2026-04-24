# Zsh Block Model — Dissolve the Zsh Module; Tools Own Their Own Shell Init

Date: 2026-04-24
Type: refactor

## Summary

Retire `modules/zsh.sh`. Distribute its responsibilities across:

- A new **Stage A** `bootstrap::zsh` that installs zsh, switches the user's
  default shell, and `touch`es empty skeleton files (`~/.zshrc`,
  `~/.zprofile`, `~/.zshenv`). These three files become **real files**, not
  symlinks.
- A new `core::ensure_block` / `core::ensure_block_absent` primitive that
  writes idempotent, uniquely-marked config blocks into text files.
- Three new modules (`fzf`, `sheldon`, `starship`), each installing its own
  package and writing its own init block into `~/.zshrc`.
- `bootstrap::homebrew` writing a `homebrew` block to `~/.zprofile` for
  persistent PATH, replacing the old "zshrc.mac symlinks one line of brew
  shellenv" approach.
- `modules/rust.sh` writing a `rust` block to `~/.zprofile` for cargo env,
  replacing the old zshenv guard line.

The Stage sequence becomes A (zsh) → B (xcode + brew, mac only) → C (detect
pm) → D (dev tools) → module loop.

## Motivation

Today's `modules/zsh.sh` is a grab-bag:

1. Installs zsh on Linux (despite the Stage C dev-tools bootstrap already
   installing it — a duplicate documented as a follow-up in the previous
   design doc).
2. Installs sheldon + starship (tools conceptually independent of the shell
   itself).
3. Symlinks a platform-split `zshrc.mac` / `zshrc.linux` into `$HOME` — these
   files are a flat list of `eval "$(...)"` lines from every tool, with
   ordering constraints embedded in whitespace and comments.
4. Implicitly owns `brew shellenv` initialization on macOS via a single line
   in `zshrc.mac`.

The module violates single responsibility in two axes: it conflates **shell
plumbing** (zsh itself, compinit) with **each tool's init line** (sheldon
source, starship init, fzf --zsh). And the symlinked zshrc has no way to say
"homebrew is responsible for line 2" — when brew's installer changes or the
user moves from Intel to Apple Silicon, the line lives far from the code
that manages brew.

A cleaner shape: each tool (brew, sheldon, starship, fzf, rust/cargo) owns
its own markered block in the appropriate zsh startup file. Adding a tool
means one module commit; removing it leaves no orphan lines. The shell
skeleton files themselves are minimal and owned by a bootstrap stage — not
a module.

## Design

The sections below are numbered 1-11 and match the brainstorming dialogue.

### 1. Architecture overview

**New:**

- Stage A `bootstrap::zsh` — install zsh (Linux only), `chsh -s $(which zsh)`
  when current login shell ≠ zsh, `touch` the three skeleton files.
- `core::ensure_block <file> <id> <content>` and
  `core::ensure_block_absent <file> <id>` added to `lib/core.sh`. Manages
  text blocks delimited by `# BEGIN dotfiles:<id>` / `# END dotfiles:<id>`.
- Three new modules: `modules/fzf.sh`, `modules/sheldon.sh`,
  `modules/starship.sh`. Each installs its package, writes its init block
  into `~/.zshrc`, and (for sheldon/starship) generates its config via the
  tool's own CLI commands rather than symlinking a repo-tracked template.

**Deleted:**

- `modules/zsh.sh`
- `config/zsh/zshrc.mac`, `config/zsh/zshrc.linux`
- `config/zsh/zshenv` (cargo env moves to rust module's zprofile block)
- `config/zsh/starship.toml` (starship generates via `starship preset`)
- `config/zsh/sheldon/plugins.toml` (sheldon generates via `sheldon init` +
  `sheldon add`)
- Empty directories `config/zsh/sheldon/` and `config/zsh/`
- `docs/modules/zsh.md`

**Modified:**

- `install.sh` — `main()` rearranged from 3-stage to 4-stage; `_MODULES`
  list updated.
- `uninstall.sh` — `_MODULES` list updated.
- `lib/bootstrap.sh` — `bootstrap::homebrew` rewritten to write a managed
  block to `~/.zprofile`.
- `modules/rust.sh` — adds one `core::ensure_block` call for the cargo env
  block; symmetric `ensure_block_absent` in uninstall.
- `README.md` — Modules table reflects the new module list.

**Core paradigm shift:**

- `~/.zshrc`, `~/.zprofile`, `~/.zshenv` change from **symlinks** (integrally
  owned by the zsh module) to **real files** (owned by bootstrap::zsh;
  contents composed from many managed blocks written by bootstrap stages
  and individual modules).
- Tool configuration files (`starship.toml`, sheldon's `plugins.toml`) stop
  being symlinked from the repo. The tool's own CLI generates them.

### 2. Stage orchestration in install.sh

```bash
main() {
  detect::os

  # Stage A: ensure zsh + shell skeleton files exist
  # - Linux: apt/dnf install zsh (brew isn't available yet)
  # - mac: zsh preinstalled, skip install
  # - both: chsh -s $(which zsh) if current shell ≠ zsh
  # - both: touch ~/.zshrc ~/.zprofile ~/.zshenv (real files, not symlinks)
  bootstrap::zsh

  # Stage B: ensure a package manager exists.
  # mac needs Xcode CLT + Homebrew; Linux's apt/dnf ships with the distro.
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    bootstrap::xcode_clt
    bootstrap::homebrew
  fi

  # Stage C: identify the package manager.
  detect::pkg_manager

  # Stage D: install dev tools every module assumes exist.
  bootstrap::dev_tools

  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  local total=${#_MODULES[@]} i=0 name
  for name in "${_MODULES[@]}"; do
    i=$((i + 1))
    install::run_module "${name}" "${i}" "${total}"
  done

  core::log INFO "Install complete."
}
```

**Ordering note.** Stage A runs before Stage C `detect::pkg_manager`, so
`bootstrap::zsh` cannot depend on `DOTFILES_PKG_MANAGER`. It does its own
`command -v apt-get` / `command -v dnf` dispatch, mirroring the pattern in
`bootstrap::dev_tools` without the `DOTFILES_PKG_MANAGER` indirection.

The stage order is fixed: zsh must come first so skeleton files exist when
later stages append blocks. brew cannot run before zsh (brew needs PATH
writes, for which zprofile must exist). detect::pkg_manager cannot run
before brew (mac's "pm" isn't installed yet). dev_tools cannot run before
detect.

`uninstall.sh` is unchanged structurally — still `detect::os` + module loop.
It does not invoke any `bootstrap::*` function; bootstrap products stay on
the machine (§8).

### 3. bootstrap::zsh function

```bash
bootstrap::zsh() {
  if ! command -v zsh >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get install -y zsh
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y zsh
    else
      core::log ERROR "zsh not found and no supported package manager to install it"
      core::log ERROR "Supported: brew (mac preinstalled), apt (Debian/Ubuntu), dnf (Fedora/RHEL)"
      return 1
    fi
    core::log INFO "zsh installed"
  else
    core::log INFO "zsh already installed"
  fi

  local current_shell
  current_shell="$(basename "${SHELL:-/bin/sh}")"
  if [[ "${current_shell}" != "zsh" ]]; then
    core::log INFO "Changing login shell to zsh (chsh — may prompt for password)"
    chsh -s "$(command -v zsh)"
  else
    core::log INFO "Login shell already zsh"
  fi

  touch "${HOME}/.zshrc" "${HOME}/.zprofile" "${HOME}/.zshenv"
}
```

**Failure modes.** zsh install failure → `return 1`, `set -e` aborts the
installer. chsh failure → bubbles via `set -e`, aborting the installer.
The user fixes the underlying issue (wrong password, zsh not in
`/etc/shells`) and re-runs. `touch` on an existing file is a no-op and
cannot fail in normal cases.

**Note on `${SHELL}` detection.** `SHELL` is populated from `/etc/passwd`
at login. After a successful `chsh` within the same install run,
`${SHELL}` remains the old value until the user opens a new session. This
is fine — the re-run guard catches "already zsh" on the next
`./install.sh` invocation (a fresh shell reads the updated passwd entry),
and the inline `chsh` itself is harmless if run redundantly (the no-op
case exits 0 with a "shell already set" message).

**What this function deliberately does NOT do:**

- Does not check or append to `/etc/shells`. On apt/dnf/mac the zsh binary
  is always already in `/etc/shells`. The rare edge case ("brew install zsh
  to replace system zsh") surfaces a clear `chsh` error and a one-line
  manual fix.
- Does not symlink or populate `~/.zshrc`, `~/.zprofile`, `~/.zshenv`
  beyond ensuring they exist. All content is written by later stages and
  modules via `core::ensure_block`.
- Does not touch `.zshrc.local` or any escape-hatch file. Deemed unnecessary
  per brainstorming.

### 4. core::ensure_block primitive

Two functions added to `lib/core.sh`.

```bash
# core::ensure_block <file> <id> <content>
#
# Idempotently writes a managed block into <file>. A block is delimited by:
#   # BEGIN dotfiles:<id>
#   <content>
#   # END dotfiles:<id>
#
# - If the block does not exist: append it (with a leading blank line for
#   readability between blocks).
# - If the block exists with different content: replace content in-place.
# - If the block exists with identical content: no-op, logs "unchanged".
# - If <file> does not exist: create it, then append.
#
# <content> is written verbatim. Callers pre-expand any variables they want
# captured at install time.
core::ensure_block() {
  local file="${1}" id="${2}" content="${3}"
  local begin="# BEGIN dotfiles:${id}"
  local end="# END dotfiles:${id}"

  [[ -f "${file}" ]] || : >"${file}"

  if ! grep -qxF "${begin}" "${file}"; then
    if [[ -s "${file}" ]]; then printf '\n' >>"${file}"; fi
    {
      printf '%s\n' "${begin}"
      printf '%s\n' "${content}"
      printf '%s\n' "${end}"
    } >>"${file}"
    core::log INFO "Added block '${id}' to ${file}"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v begin="${begin}" -v end="${end}" -v content="${content}" '
    $0 == begin { in_block=1; print; print content; next }
    $0 == end   { in_block=0; print; next }
    !in_block   { print }
  ' "${file}" >"${tmp}"

  if cmp -s "${file}" "${tmp}"; then
    rm -f "${tmp}"
    core::log INFO "Block '${id}' in ${file} unchanged"
  else
    mv "${tmp}" "${file}"
    core::log INFO "Updated block '${id}' in ${file}"
  fi
}

# core::ensure_block_absent <file> <id>
# Removes the named block and its markers. No-op if file or block absent.
core::ensure_block_absent() {
  local file="${1}" id="${2}"
  local begin="# BEGIN dotfiles:${id}"
  local end="# END dotfiles:${id}"

  [[ -f "${file}" ]] || return 0
  grep -qxF "${begin}" "${file}" || return 0

  local tmp
  tmp="$(mktemp)"
  awk -v begin="${begin}" -v end="${end}" '
    $0 == begin { in_block=1; next }
    $0 == end   { in_block=0; next }
    !in_block   { print }
  ' "${file}" >"${tmp}"

  mv "${tmp}" "${file}"
  core::log INFO "Removed block '${id}' from ${file}"
}
```

**Design choices:**

- `<content>` is the last argument so callers can write heredocs inline.
- Content is written verbatim — no shell expansion at write time. Callers
  decide whether to pre-expand `${brew_prefix}` (yes) or leave `${HOME}`
  for the shell to expand at runtime (yes, with `\${HOME}`).
- `awk`, not `sed -i`, because `sed -i` has BSD/GNU incompatibility. `awk`
  behaves identically on mac and Linux.
- `grep -qxF` matches the full line (`-x`) as a fixed string (`-F`), so
  user comments like `# BEGIN dotfiles:foo-example` cannot accidentally
  match an id.
- Three-state logging (added / updated / unchanged) makes it obvious what
  a re-run is doing.
- Writing the tempfile with `awk` then `mv` is atomic on the same
  filesystem. No partial-write risk.

**Risk acknowledged.** If the user hand-edits inside a managed block, the
next `install.sh` will overwrite. Markers should carry a "managed by
dotfiles — do not edit" comment. Out-of-block edits are preserved.

### 5. New modules: fzf / sheldon / starship

Each module follows the shape: install package via `core::pkg_install`,
write init block via `core::ensure_block`, and for sheldon/starship
additionally call the tool's CLI to generate its configuration file.
Uninstall removes only the init block; the package and generated config
files are preserved.

#### modules/fzf.sh

```bash
#!/usr/bin/env bash
# modules/fzf.sh — fzf fuzzy finder
# Platform: all
# shellcheck disable=SC2034
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="fzf"
MODULE_DESC="fzf fuzzy finder with zsh key bindings"
MODULE_PLATFORM="all"
LINKS=()

install() {
  core::pkg_install fzf
  core::ensure_block "${HOME}/.zshrc" "fzf" 'eval "$(fzf --zsh)"'
}

uninstall() {
  core::ensure_block_absent "${HOME}/.zshrc" "fzf"
}
```

**Ordering.** fzf must appear before sheldon in `_MODULES` because
sheldon's `fzf-tab` plugin requires the fzf binary at runtime.

#### modules/sheldon.sh

```bash
#!/usr/bin/env bash
# modules/sheldon.sh — sheldon zsh plugin manager
# Platform: all
# shellcheck disable=SC2034
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="sheldon"
MODULE_DESC="sheldon plugin manager with curated plugin set"
MODULE_PLATFORM="all"
LINKS=()

_SHELDON_PLUGINS=(
  "zsh-users/zsh-autosuggestions"
  "zsh-users/zsh-syntax-highlighting"
  "zsh-users/zsh-completions"
  "Aloxaf/fzf-tab"
  "mattmc3/zsh-safe-rm"
  "rupa/z"
  "zsh-users/zsh-history-substring-search"
)

install() {
  core::pkg_install sheldon

  local config="${HOME}/.config/sheldon/plugins.toml"
  if [[ ! -f "${config}" ]]; then
    sheldon init --shell zsh
  fi

  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    sheldon add "${name}" --github "${plugin}" >/dev/null 2>&1 || true
  done

  # Patch zsh-completions to use fpath (sheldon CLI has no direct flag for
  # this). Without fpath, zsh-completions causes "insecure directories"
  # permission warnings and ineffective completion.
  _sheldon::patch_fpath_for_zsh_completions "${config}"

  core::ensure_block "${HOME}/.zshrc" "sheldon" "$(
    cat <<'BLOCK'
eval "$(sheldon source)"

# Completion system (after sheldon so fpath is fully populated)
autoload -Uz compinit && compinit

# History substring search key bindings (plugin loaded above)
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down
BLOCK
  )"
}

uninstall() {
  core::ensure_block_absent "${HOME}/.zshrc" "sheldon"
}

# Module-local helper: patch the zsh-completions plugin to use fpath-apply.
_sheldon::patch_fpath_for_zsh_completions() {
  local config="${1}"
  # Already patched — no-op.
  if awk '/^\[plugins\.zsh-completions\]/ { in_s=1; next } /^\[/ { in_s=0 } in_s && /^apply = \["fpath"\]/ { f=1 } END { exit !f }' "${config}"; then
    return 0
  fi
  # Insert the apply line directly after the [plugins.zsh-completions] header.
  local tmp
  tmp="$(mktemp)"
  awk '
    /^\[plugins\.zsh-completions\]/ {
      print
      print "apply = [\"fpath\"]"
      next
    }
    { print }
  ' "${config}" >"${tmp}"
  mv "${tmp}" "${config}"
  core::log INFO "Patched zsh-completions to use fpath in ${config}"
}
```

**Risk acknowledged.** The TOML patch is fragile: if sheldon changes its
output format (different section header, different key layout), the `awk`
heuristic breaks. Design doc §8 lists this as known tech debt; fix when
sheldon's format actually changes.

#### modules/starship.sh

```bash
#!/usr/bin/env bash
# modules/starship.sh — Starship prompt (catppuccin-powerline preset)
# Platform: all
# shellcheck disable=SC2034
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="starship"
MODULE_DESC="Starship prompt (catppuccin-powerline preset)"
MODULE_PLATFORM="all"
LINKS=()

_STARSHIP_PRESET="catppuccin-powerline"

install() {
  core::pkg_install starship

  local config="${HOME}/.config/starship.toml"
  if [[ ! -f "${config}" ]]; then
    mkdir -p "$(dirname "${config}")"
    starship preset "${_STARSHIP_PRESET}" --output "${config}"
    core::log INFO "Generated starship.toml from preset ${_STARSHIP_PRESET}"
  fi

  core::ensure_block "${HOME}/.zshrc" "starship" 'eval "$(starship init zsh)"'
}

uninstall() {
  core::ensure_block_absent "${HOME}/.zshrc" "starship"
}
```

The preset name is a module-local constant; change it by editing
`modules/starship.sh` and re-running `install.sh`. Existing
`~/.config/starship.toml` is not regenerated if already present — users
who've tweaked the prompt keep their tweaks.

### 6. bootstrap::homebrew rewrite

```bash
bootstrap::homebrew() {
  if command -v brew >/dev/null 2>&1; then
    core::log INFO "Homebrew already installed"
    return 0
  fi

  core::log INFO "Installing Homebrew (official installer)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  local brew_prefix
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_prefix=/opt/homebrew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_prefix=/usr/local
  else
    core::log ERROR "Homebrew installer completed but brew binary not found"
    core::log ERROR "Checked /opt/homebrew/bin/brew and /usr/local/bin/brew"
    return 1
  fi

  # Persist shellenv for future login shells.
  core::ensure_block "${HOME}/.zprofile" "homebrew" \
    "eval \"\$(${brew_prefix}/bin/brew shellenv)\""

  # Activate for the rest of THIS install run.
  eval "$("${brew_prefix}/bin/brew" shellenv)"

  core::log INFO "Homebrew installed; shellenv wired into ~/.zprofile"
}
```

**Differences from the old version:**

- The brew prefix is resolved once into a variable; the variable feeds both
  the `core::ensure_block` call and the `eval`.
- Persistent PATH wiring now lives in `~/.zprofile` (written by bootstrap)
  rather than the zsh module's `zshrc.mac` symlink. This is what Homebrew's
  own installer's "Next steps" guidance tells users to do manually — the
  script does it for them.
- Apple Silicon → Intel (or reverse) self-heals: `core::ensure_block`
  detects the changed content and rewrites the line.

**Escaping.** Content is `"eval \"\$(${brew_prefix}/bin/brew shellenv)\""`.
`${brew_prefix}` expands at bash evaluation time (install-time); `$( ... )`
stays literal and is evaluated at zsh startup. Quotes inside the
double-quoted string are escaped.

#### Cargo env relocated to rust module

`modules/rust.sh` gains (at the end of `install()`):

```bash
core::ensure_block "${HOME}/.zprofile" "rust" \
  '[[ -f "${HOME}/.cargo/env" ]] && . "${HOME}/.cargo/env"'
```

`uninstall()` gains:

```bash
core::ensure_block_absent "${HOME}/.zprofile" "rust"
```

Content keeps `${HOME}` literal so zsh expands it at runtime, not bash at
install-time. Symmetric with brew: the module that installs the tool owns
the shell init that puts the tool on PATH.

### 7. Uninstall semantics + idempotency

#### Uninstall

Modules clean up only blocks they wrote; they leave packages, tool-generated
config files, and bootstrap products alone.

| Module | uninstall() | Does NOT |
|---|---|---|
| fzf | `core::ensure_block_absent ~/.zshrc fzf` | remove fzf package |
| sheldon | `core::ensure_block_absent ~/.zshrc sheldon` | remove sheldon package; delete `~/.config/sheldon/plugins.toml` |
| starship | `core::ensure_block_absent ~/.zshrc starship` | remove starship package; delete `~/.config/starship.toml` |
| rust | existing rustup cleanup (user-run) + `core::ensure_block_absent ~/.zprofile rust` | |

Bootstrap products (zsh, chsh, CLT, Homebrew, `~/.zprofile`'s `homebrew`
block, dev tools) are never uninstalled. See §8 for rationale.

#### Idempotency guarantees for `./install.sh` re-run

| Operation | Idempotency mechanism |
|---|---|
| `bootstrap::zsh` install zsh | `command -v zsh` guard |
| `bootstrap::zsh` chsh | `basename "${SHELL}"` check |
| `bootstrap::zsh` touch skeletons | `touch` is idempotent |
| `bootstrap::xcode_clt` | `xcode-select -p` guard |
| `bootstrap::homebrew` | `command -v brew` guard + `core::ensure_block` |
| `bootstrap::dev_tools` | native pm "already installed" short-circuits |
| module `core::pkg_install` | per-pm already-installed check |
| module `core::ensure_block` | three-state (add / update / unchanged) |
| `sheldon add` repeated calls | `|| true` swallows "already added" errors |
| sheldon apply=fpath patch | awk check before edit |
| `starship preset --output` | `[[ ! -f "${config}" ]]` guard |
| module `LINKS` | `core::symlink` handles |

#### User-edit conflict handling

- Inside a managed block: overwritten on next run. Marker comment warns.
- Outside any block: preserved.
- User deletes an entire block: re-appended on next run.

### 8. Deliberate asymmetries (not bugs)

**Bootstrap products are not uninstalled.** If a user decides to remove
dotfiles entirely (`./uninstall.sh`), their terminal must still work. That
means zsh, brew, CLT, dev tools, and the bootstrap-owned `homebrew` block
in `~/.zprofile` all stay. The boundary:

- **bootstrap** installs the machine's baseline: without it the user can't
  open a working terminal.
- **modules** install dotfiles-specific configuration: without them the
  terminal still works, just without the niceties.

`./uninstall.sh` removes the module-owned layer; bootstrap is permanent
once installed.

**Tool-generated config files are not deleted on module uninstall.** A user
may have tweaked `starship.toml` or sheldon's `plugins.toml`. Deleting them
would destroy user work without recovery. The module uninstall removes the
hook that loads the tool (`eval "$(starship init zsh)"`) but leaves the
config sitting on disk for the user to reuse or delete manually.

**Stage A cannot use `DOTFILES_PKG_MANAGER`.** Detection runs in Stage C.
`bootstrap::zsh` duplicates the pm check via `command -v apt-get` / `dnf`.
This is the same approach `bootstrap::dev_tools` uses pre-refactor; it's
consistent with existing bootstrap patterns.

**`uninstall.sh` runs no bootstrap stages.** It can succeed on a broken
machine (brew gone, default shell reverted) and still clean up dotfiles
artifacts. Uninstall cares about symlink and block removal, nothing more.

### 9. Complete file inventory

| File | Status | Notes |
|---|---|---|
| `lib/core.sh` | modify | add `core::ensure_block` + `core::ensure_block_absent` |
| `lib/bootstrap.sh` | modify | add `bootstrap::zsh`; rewrite `bootstrap::homebrew` to use `core::ensure_block` |
| `install.sh` | modify | main() 4-stage rearrangement; `_MODULES` updated |
| `uninstall.sh` | modify | `_MODULES` updated (drop zsh, add fzf/sheldon/starship) |
| `modules/fzf.sh` | new | fzf module |
| `modules/sheldon.sh` | new | sheldon module with TOML patch helper |
| `modules/starship.sh` | new | starship module |
| `modules/rust.sh` | modify | add cargo zprofile block in install/uninstall |
| `modules/zsh.sh` | **delete** | replaced by bootstrap::zsh + three new modules |
| `config/zsh/zshrc.mac` | **delete** | replaced by managed blocks |
| `config/zsh/zshrc.linux` | **delete** | replaced by managed blocks |
| `config/zsh/zshenv` | **delete** | cargo env moves to rust module |
| `config/zsh/starship.toml` | **delete** | starship generates via preset |
| `config/zsh/sheldon/plugins.toml` | **delete** | sheldon generates via init/add |
| `config/zsh/sheldon/` | **delete** | empty directory |
| `config/zsh/` | **delete** | empty directory |
| `README.md` | modify | Modules table reflects new list |
| `docs/modules/zsh.md` | **delete** | module no longer exists |
| `docs/modules/fzf.md` | new | module documentation |
| `docs/modules/sheldon.md` | new | module documentation |
| `docs/modules/starship.md` | new | module documentation |
| `docs/modules/rust.md` | modify | document the new zprofile block |

**Net size.** ~9 new files, ~6 modified, ~9 deleted (including two empty
directories). LOC shifts from "centralized 100-line zshrc + single-module
install" to "distributed per-tool modules + two core primitives (~80 LOC)".

### 10. Testing approach

No test framework (project convention). Validation is:

**Static checks** on all touched shell files:
- `bash -n`
- `shellcheck`
- `shfmt -d`

**Smoke tests** (ad-hoc bash snippets):

1. `core::ensure_block` — 4 scenarios on a throwaway file in `/tmp`:
   - File does not exist → block created.
   - File exists, block absent → block appended with leading blank line.
   - Block exists, content identical → "unchanged" log, no file change.
   - Block exists, content different → "updated" log, in-place replace.

2. `core::ensure_block_absent` — 3 scenarios:
   - File does not exist → no-op, exit 0.
   - Block does not exist → no-op, exit 0.
   - Block exists → removed, surrounding content preserved.

3. Re-source safety: source each lib file three times under strict mode.

4. Marker strictness: a user-written line like `# BEGIN dotfiles:fake-id`
   inserted outside any block must not be matched by `grep -qxF` for a
   different id.

**Manual trial run on mac** (current machine, already has zsh / brew / most
dev tools):
- Expect Stage A to log "zsh already installed" and "Login shell already zsh".
- Expect Stage B to log "already installed" for brew; the `homebrew` block
  to be added to `~/.zprofile`.
- Expect Stage D's `cmake meson ninja gettext` to be idempotent brew calls.
- Expect fzf / sheldon / starship modules to write their blocks to `~/.zshrc`.
- Expect rust module to add the `rust` block to `~/.zprofile`.
- Open a fresh terminal: prompt is catppuccin-powerline, Ctrl+R triggers
  fzf history search, `sheldon source`'d plugins are active.

**No legacy migration.** The repository has no users; no prior state to
upgrade. Users starting fresh will see the new behaviour from their first
`./install.sh` run.

### 11. Non-goals

1. **Do not change the module interface.** `MODULE_NAME`, `MODULE_DESC`,
   `MODULE_PLATFORM`, `LINKS`, `install()`, `uninstall()` — unchanged.
2. **Do not change `install::run_module` or `uninstall::run_module`.** Only
   `main()`'s orchestration and `_MODULES` list change.
3. **Do not add advanced features to `core::ensure_block`.** No
   before/after anchors, no conditional blocks, no dry-run, no ordering
   metadata. Three states (add / update / unchanged) plus the absent
   variant is the complete contract.
4. **Do not delete bootstrap products on uninstall.** zsh, brew, CLT, dev
   tools, and the `homebrew` block in `~/.zprofile` persist across
   `./uninstall.sh`.
5. **Do not support fish, bash, or other shells.** Zsh is the only supported
   interactive shell.
6. **Do not add a `~/.zshrc.local` escape hatch.** Users who want one can
   write their own block.
7. **Do not modify modules unrelated to shell init.** `modules/git.sh`,
   `modules/ghostty.sh`, `modules/tmux.sh`, `modules/nvim.sh` are untouched.
8. **Keep `modules/rust.sh` changes minimal.** Two new calls
   (`core::ensure_block` in install, `core::ensure_block_absent` in
   uninstall) plus one doc line. No rework of rustup installation.
9. **Do not revert to symlinking sheldon's `plugins.toml`.** TOML-patch via
   `awk` is the accepted approach. Breakage from sheldon format changes is
   accepted tech debt.
10. **Do not introduce a `_BLOCK_ORDER` array or similar metadata.** Block
    ordering in each file is a natural consequence of `_MODULES` order and
    bootstrap stage order. No separate ordering layer.

## Risks and edge cases

1. **User edits inside a managed block.** Overwritten on next install.
   Marker comment will read `# BEGIN dotfiles:<id> (managed by dotfiles —
   do not edit)`.

2. **sheldon's TOML output format changes.** The `_sheldon::patch_fpath_for_zsh_completions`
   helper's awk heuristic breaks. Fix when it breaks; don't over-engineer
   up front.

3. **chsh fails on first run.** User password wrong, or zsh not in
   `/etc/shells` (rare — see §3). `set -e` aborts install. User re-runs
   after fixing the password / adding to `/etc/shells`.

4. **Apple Silicon ↔ Intel migration.** `brew_prefix` differs between the
   two; `core::ensure_block` detects the difference and rewrites the
   `homebrew` block.

5. **User deletes a bootstrap-written block manually.** Next install
   re-creates it (grep for BEGIN marker fails → append path).

6. **Block written to `~/.zshenv` is never read because we only write to
   `~/.zshrc` and `~/.zprofile`.** No bug; the skeleton file exists as a
   placeholder for future env lines. It stays empty in practice.

7. **`awk` on mac uses BSD awk; on Linux, GNU awk.** Both implementations
   support the used syntax (`-v`, pattern-action, next, print). No
   portability concerns.

## Open questions / future work

- Possibly add `modules/zsh.sh` **back** in a minimal form later, purely to
  host the `ssh()` function and any user-level zsh tweaks — only if/when
  there's an actual need. For now the user said explicitly: no ssh wrapper,
  no .zshrc.local escape hatch.
- The `~/.zshenv` skeleton is always empty after this change. If still
  empty after a year, remove it from `bootstrap::zsh`'s `touch` list.
- Consider a `scripts/block-list` helper that greps all blocks currently
  managed in `~/.zshrc` and `~/.zprofile`, useful for debugging. Not in
  scope for this refactor.
