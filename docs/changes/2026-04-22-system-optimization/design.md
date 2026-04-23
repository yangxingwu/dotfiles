# System Optimization — Simplify Installer, Module Interface, and Style

Date: 2026-04-22
Type: refactor (cross-cutting)

## Summary

A single-pass refactor that tightens four long-standing pain points at once:

1. **oh-my-tmux** install path replaced by the upstream one-liner.
2. **`install.sh` / `uninstall.sh`** lose `--module` and `--dry-run` flags.
   The CLI becomes a single, argumentless entry point.
3. **`lib/preflight.sh`** is deleted. Conflict handling moves into
   `core::symlink`, where it happens per-symlink and interactively.
4. **Shell script style** is unified: `case` branches indent 2 spaces;
   namespace tables in `shell-style.md` catch up with reality.

Additional consolidation, enabled by the above:

- `DRY_RUN` is removed from every layer (core lib, modules, orchestrator).
- Module interface collapses from `pre_install / install / post_install`
  to `install / uninstall`. Both hooks are required; `{ :; }` for no-op.
- Execution order: `install()` then LINKS on install; LINKS then
  `uninstall()` on uninstall.
- `core.sh` gains `core::check_installed` and `core::require_version` so
  every module does binary detection the same way.
- `config/git/gitconfig` keeps `[core] hooksPath = ~/.git-hooks` (already
  present); `git.sh`'s redundant `post_install` is deleted.
- `starship.toml` is tracked in the repo (`config/zsh/starship.toml`);
  `zsh.sh`'s `post_install` preset generation is deleted.
- `zsh.sh` platform-split `.zshrc` is expressed as LINKS entries at module
  top level, not by manually calling `core::symlink` in `post_install`.
- `README.md` module table trimmed to the 5 user-facing modules
  (ghostty / git / nvim / tmux / zsh). `rust` still runs as part of
  `_MODULES` — it is required before `nvim` so that `cargo` is
  available for `tree-sitter-cli` — but it is not advertised on the
  README as a user-chosen module.

## Motivation

The current code expresses too many concerns in too many places:

- A conflict may be handled by `preflight.sh` (pre-scan), by `core::symlink`
  (during LINKS), by a module's `pre_install` (e.g. `zsh.sh` backing up
  `~/.zshenv`), or by hand-rolled `ln -sf` inside `post_install`
  (e.g. `tmux.sh`). Four paths for one concept.
- `DRY_RUN` doubles every destructive function with a logging branch and
  adds a skip path to `preflight.sh`. The cost is high and the value is low:
  the installer is already idempotent, conflicts are caught interactively,
  and backups go to a timestamped directory. "Preview" does not earn its
  keep.
- `--module` collides with the module-ordering guarantee
  (`rust → nvim`) — running `--module nvim` on a clean machine without
  `cargo` already present silently skips `tree-sitter-cli`. The flag is a
  footgun masquerading as a convenience.
- `tmux.sh::post_install` re-implements `mkdir -p`, `ln -sf`, and
  `readlink`-based idempotency checks that `core::symlink` already handles.
  The upstream project has an official installer that does this correctly;
  we should call it.
- Style drift shows up most loudly in `case` branch indentation
  (`install.sh` flat, `uninstall.sh` indented, `.shfmt.toml` says indented).
  `.claude/rules/shell-style.md` doesn't list `install::` or `uninstall::`
  namespaces that the orchestrator actually uses.

## Design

### 1. Module interface (new)

```bash
#!/usr/bin/env bash
# modules/<name>.sh
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="<name>"                 # required; must equal filename stem
MODULE_DESC="<one-line description>" # required
MODULE_PLATFORM="all|mac|linux"      # required

LINKS=(
  "config/<name>/file:${HOME}/.config/<name>/file"
)

install()   { :; }   # required
uninstall() { :; }   # required
```

Both hooks are required. A module with nothing to do still writes `{ :; }`
so the interface stays uniform and visible.

### 2. Execution order

| Entry point | Order |
|---|---|
| `./install.sh` | `install()` → LINKS |
| `./uninstall.sh` | LINKS → `uninstall()` |

Rationale: `install()` may call upstream installers that produce files
inside `${HOME}` (e.g. oh-my-tmux `cp` of `.tmux.conf.local`). Running
LINKS after `install()` lets our repo copies cleanly override those side
products. For `uninstall`, the reverse — relinquish ownership first
(remove symlinks), then tear down external side effects.

### 3. Conflict handling

All symlink conflicts are resolved in one place: `core::symlink`. When
the target exists but is not our symlink:

```
Conflict: ~/.zshrc exists (not managed by dotfiles)
  [b] backup to ~/.dotfiles-backup/<ts>/ and replace
  [s] skip this symlink (existing file preserved)
  [q] quit installer
Choice:
```

- `b` — call `core::backup`, then `ln -sf`
- `s` — log a WARN, leave user's file alone, continue with the
  remaining LINKS entries and subsequent modules (the current module
  may end up partially installed; user accepts that risk)
- `q` — exit the installer with status 1; user cleans up and re-runs

`pre_install`-style preemptive backup (as `zsh.sh` currently does for
`~/.zshenv`) disappears — the user sees the conflict at the LINKS step
and decides.

`lib/preflight.sh` is deleted in full. Its responsibilities
(scanning, reporting, interactive resolution, skip-list) all either
move into `core::symlink` (per-item) or lose their reason to exist
along with `DRY_RUN`.

### 4. DRY_RUN removal

`DRY_RUN` is removed from every file:

- `lib/core.sh`: `DRY` log level, `_CORE_CYAN`, every
  `[[ "${DRY_RUN:-0}" == "1" ]]` branch in `core::symlink`,
  `core::backup`, `core::pkg_install`
- `install.sh`: `--dry-run` flag, `DRY_RUN` export, all DRY logs
- `uninstall.sh`: same
- `modules/*.sh`: every DRY branch

The installer is idempotent and conflicts are caught interactively, so
"preview" adds no safety. Removing `DRY_RUN` removes ~40 lines of
branching logic across the repo.

### 5. CLI simplification

`install.sh` and `uninstall.sh` take no arguments. Running either is
an all-or-nothing operation over `_MODULES`. Removed:

- `--dry-run`
- `--module <name>`
- `--help` / `-h`
- argparse functions, usage text, per-flag error paths
- interrupt trap (bash's default `INT` handling is sufficient)

Orchestrator size targets:

- `install.sh`: ~70 lines (from ~185)
- `uninstall.sh`: ~40 lines (from ~115)

### 6. New core helpers

```bash
# core::check_installed <binary>
# Returns 0 if the binary is on PATH, 1 otherwise.
core::check_installed() {
  command -v "$1" &>/dev/null
}

# core::require_version <binary> <min-major> <min-minor>
# Returns 0 if `<binary> --version` reports >= min.min, 1 otherwise.
# Parses the first "<digits>.<digits>" substring on the first output line.
core::require_version() {
  local bin="$1" min_major="$2" min_minor="$3"
  local version major minor
  version="$("${bin}" --version 2>/dev/null | head -1 |
    grep -oE '[0-9]+\.[0-9]+' || true)"
  [[ -z "${version}" ]] && return 1
  major="${version%.*}"
  minor="${version#*.}"
  ((major > min_major)) && return 0
  ((major == min_major)) && ((minor >= min_minor)) && return 0
  return 1
}
```

These replace scattered `command -v` / `which` / manual version regex
usage inside modules with a single uniform spelling.

### 7. Module-by-module changes

#### ghostty.sh
- `pre_install`/`post_install` → `install` / `uninstall`, both `{ :; }`.
- LINKS unchanged.

#### git.sh
- `post_install` deleted (the `git config --global core.hooksPath`
  line is redundant — `config/git/gitconfig` already declares
  `[core] hooksPath = ~/.git-hooks`).
- `install()`: `core::pkg_install git`.
- `uninstall()`: `{ :; }`.

#### rust.sh
- Merge `post_install` into `install`: after rustup install, source
  `~/.cargo/env` in the same hook so cargo is on PATH for the
  nvim module that runs next.
- Use `core::check_installed rustup` instead of `command -v rustup`.
- `uninstall()`: `{ :; }`. Documented in README: `rustup self uninstall`.

#### nvim.sh
- Merge the three old hooks into a single `install()`:
  1. `core::pkg_install` LazyVim runtime deps (ripgrep/fd/lazygit/node/
     shfmt/shellcheck)
  2. `cargo install --locked tree-sitter-cli` if cargo present
  3. Neovim detection via
     `core::check_installed nvim && core::require_version nvim 0 9`;
     interactive pkg-manager vs source-build prompt on miss (behaviour
     preserved from today)
  4. Clone `yangxingwu/neovim-lua-config#LazyVimV2` to `~/.config/nvim`
     if not already a git checkout there
- `uninstall()`: `rm -rf ~/.config/nvim` if `.git` present.

#### tmux.sh
- `post_install` deleted; manual `git clone` + `ln -sf` + `mkdir -p`
  logic replaced by upstream installer:

  ```bash
  install() {
    core::pkg_install tmux
    if [[ -d "${_TMUX_CLONE_DIR}/.git" ]]; then
      core::log INFO "oh-my-tmux already present — skipping"
      return 0
    fi
    mkdir -p "${HOME}/.config/tmux"
    curl -fsSL "${_TMUX_INSTALL_URL}" | bash
    # oh-my-tmux cp's a starter tmux.conf.local; delete it only if it is
    # a real file (not already our symlink from a prior run), so LINKS
    # can take over without a spurious conflict prompt.
    if [[ -f "${HOME}/.config/tmux/tmux.conf.local" ]] &&
      [[ ! -L "${HOME}/.config/tmux/tmux.conf.local" ]]; then
      rm "${HOME}/.config/tmux/tmux.conf.local"
    fi
  }
  ```

- `uninstall()`: `rm -rf ~/.config/tmux/.tmux`;
  `rm -f ~/.config/tmux/tmux.conf` if a symlink.
- LINKS unchanged (`tmux.conf.local` only).
- Constants:
  - `_TMUX_INSTALL_URL="https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh"`
  - `_TMUX_CLONE_DIR="${HOME}/.config/tmux/.tmux"`

#### zsh.sh
- `starship.toml` tracked in repo as `config/zsh/starship.toml`
  (generated once via `starship preset catppuccin-powerline`).
- LINKS built conditionally at module top level:

  ```bash
  LINKS=(
    "config/zsh/sheldon/plugins.toml:${HOME}/.config/sheldon/plugins.toml"
    "config/zsh/starship.toml:${HOME}/.config/starship.toml"
    "config/zsh/zshenv:${HOME}/.zshenv"
  )
  case "${DOTFILES_OS}" in
    mac)   LINKS+=("config/zsh/zshrc.mac:${HOME}/.zshrc") ;;
    linux) LINKS+=("config/zsh/zshrc.linux:${HOME}/.zshrc") ;;
  esac
  ```

- `install()`: `core::pkg_install sheldon starship` (+ `zsh` on Linux).
- `uninstall()`: `{ :; }`.
- `pre_install` proactive backup of `~/.zshenv` deleted — conflict now
  handled by `core::symlink` on first run.
- `post_install` deleted (starship preset generation and platform-split
  zshrc both expressed differently now).

### 8. Style unification

- `.shfmt.toml` already sets `switch-case-indent = true`. Code is
  rewritten to match: `case` items indent 2 spaces, bodies 4 spaces.
- `.claude/rules/shell-style.md`:
  - Namespace table adds `install::`, `uninstall::`, removes `preflight::`.
  - New "Case Indentation" section with correct/wrong examples.
  - "DRY_RUN Pattern" section deleted.

### 9. Documentation sync

| File | Change |
|---|---|
| `CLAUDE.md` | Module interface contract rewritten; DRY_RUN invariant removed |
| `.claude/rules/shell-style.md` | Namespace table, case indent, DRY_RUN section |
| `.claude/commands/new-module.md` | Scaffold emits `install`/`uninstall`; remove DEPS / pre_install / post_install remnants |
| `README.md` | Drop `--dry-run`/`--module` examples; 5-module table; rewrite Conflict Handling; add Manual Cleanup After Uninstall |
| `CONTRIBUTING.md` | Remove `--module <name> --dry-run` example; fix "fill in LINKS, DEPS" wording to "fill in LINKS, install()" |
| `docs/modules/ghostty.md` | hooks table → install/uninstall |
| `docs/modules/git.md` | hooks table; note that hooksPath lives in `gitconfig`, not a hook |
| `docs/modules/nvim.md` | hooks table; describe single merged install() |
| `docs/modules/tmux.md` | hooks table; replace post_install narrative with "install() calls upstream one-liner"; drop `~/.local/share/tmux/...` path reference (clone is now at `~/.config/tmux/.tmux/`) |
| `docs/modules/zsh.md` | hooks table; add starship.toml to LINKS list |

## Non-goals

- No new modules.
- No change to the `DOTFILES_OS`/`DOTFILES_PKG_MANAGER` detection in
  `lib/detect.sh` (it works; style is already fine).
- No change to how `core::backup` names backups
  (`~/.dotfiles-backup/YYYYMMDD-HHMMSS/`).
- No automatic uninstall of rust, packages installed via pkg manager,
  or sheldon plugins. README documents the manual cleanup commands.
- No test harness added in this pass (out of scope; worth its own design
  later).

## File-by-file change inventory

```
DELETE:
  lib/preflight.sh

MODIFY:
  install.sh                             # ~185 → ~70 lines; no flags; no DRY_RUN
  uninstall.sh                           # ~115 → ~40 lines; no flags; no DRY_RUN
  lib/core.sh                            # drop DRY branches; add check_installed / require_version; core::symlink interactive conflict prompt
  modules/ghostty.sh                     # 3-hook → 2-hook (both no-op)
  modules/git.sh                         # drop post_install
  modules/rust.sh                        # merge post_install into install; use core::check_installed
  modules/nvim.sh                        # merge 3 hooks into install; use new helpers
  modules/tmux.sh                        # use upstream curl | bash; simple uninstall
  modules/zsh.sh                         # platform-split LINKS; starship.toml as LINK; drop pre/post_install
  config/git/gitconfig                   # (verify only — hooksPath already present)
  CLAUDE.md
  .claude/rules/shell-style.md
  .claude/commands/new-module.md
  README.md
  CONTRIBUTING.md
  docs/modules/ghostty.md
  docs/modules/git.md
  docs/modules/nvim.md
  docs/modules/tmux.md
  docs/modules/zsh.md

CREATE:
  config/zsh/starship.toml               # generated once via `starship preset catppuccin-powerline`
```

## Migration & backward compatibility

Not applicable — single-user repo, no downstream consumers. A one-shot
commit that replaces everything at once. Users re-run `./install.sh`;
the interactive conflict prompt handles any state drift.

## Open risks

1. **oh-my-tmux upstream one-liner may change path or behaviour.** The
   script is fetched fresh each install (`curl -fsSL`). If upstream
   reorganises install locations, our `_TMUX_CLONE_DIR` constant and the
   `rm` of the starter `tmux.conf.local` would need adjustment. Low
   frequency of change; easy to fix when it hits.
2. **`core::require_version` version parser is naïve** — first
   `digits.digits` on first line. Works for nvim (`NVIM v0.10.2`),
   would need revisiting for tools that print their version differently.
   We only use it for nvim today, so accept the narrow fit.
3. **`[s] skip` leaves the module partially installed.** User sees a
   WARN but could still hit runtime errors (e.g. skipping `~/.zshrc` but
   linking `~/.zshenv`). Acceptable: explicit in the WARN text; user
   accepted risk by choosing `s`.
4. **`config/git/gitconfig` contains a hard-coded `user.email`** (from
   the current working tree). Not in scope for this refactor — noted for
   a future "machine-specific git user" module design.
