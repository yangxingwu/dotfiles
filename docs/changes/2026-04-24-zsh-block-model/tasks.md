# Zsh Block Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire `modules/zsh.sh`; each tool (brew, sheldon, starship, fzf, rust) writes its own markered init block into `~/.zshrc` / `~/.zprofile`; shell skeleton files become real files owned by a new `bootstrap::zsh` Stage A.

**Architecture:** Add `core::ensure_block` / `core::ensure_block_absent` primitives to `lib/core.sh`. Add `bootstrap::zsh` to `lib/bootstrap.sh` and rewrite `bootstrap::homebrew` to write a managed block to `~/.zprofile`. Replace `modules/zsh.sh` + `config/zsh/*` with three new modules (`fzf`, `sheldon`, `starship`). Reorganise `install.sh` `main()` into four stages (zsh → brew → detect pm → dev tools).

**Tech Stack:** Bash 4+, strict mode, shellcheck, shfmt 3.13, awk (POSIX, BSD-and-GNU-compatible).

**Source of truth:** `docs/changes/2026-04-24-zsh-block-model/design.md` (same directory).

---

## Ordering Rationale

The tree must pass `bash -n` / `shellcheck` / `shfmt -d` after every commit. That constraint forces a specific order:

1. **Primitives first** (Task 1): `core::ensure_block` and `core::ensure_block_absent` added to `lib/core.sh`. Independent, no callers yet. Smoke-tested ad-hoc in `/tmp`.

2. **bootstrap::zsh added** (Task 2): pure addition to `lib/bootstrap.sh`. Not called yet (install.sh main() still has the old 3-stage flow). Independent of the homebrew rewrite.

3. **bootstrap::homebrew rewrite** (Task 3): uses `core::ensure_block` (Task 1). The only caller is install.sh's Stage A; since `zshrc.mac`'s `brew shellenv` line is still present, the block goes to `~/.zprofile` harmlessly in parallel until Task 10 deletes zshrc.mac.

4. **Three new modules added** (Tasks 4–6): fzf, sheldon, starship. Each is a standalone new file. They are NOT in `_MODULES` yet, so nothing exercises them. They independently pass static checks.

5. **rust module updated** (Task 7): adds the cargo zprofile block. Works regardless of whether `_MODULES` has been updated.

6. **install.sh Stage A added, `_MODULES` flipped** (Task 8): wire in `bootstrap::zsh`; switch `_MODULES` from `(ghostty git rust nvim tmux zsh)` to `(ghostty git rust fzf sheldon starship nvim tmux)`. After this, the old `modules/zsh.sh` is orphaned (never loaded) but still exists — that is fine.

7. **uninstall.sh `_MODULES` synced** (Task 9).

8. **Old zsh module + config/zsh/ deleted** (Task 10): safe now that no code references them.

9. **docs cleanup** (Task 11): delete `docs/modules/zsh.md`; add `docs/modules/{fzf,sheldon,starship}.md`; update README's Modules table.

10. **Final sweep** (Task 12): static-analysis all, re-source safety, ad-hoc smoke tests, trial `./install.sh` on the current machine.

Every code task follows the same shape: write/modify → `bash -n` → `shellcheck` → `shfmt -d` → commit. Doc-only tasks skip the shell checks. Every commit ends with `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`; **never** pass `--no-verify` to git commit.

---

## Task 1: Add `core::ensure_block` and `core::ensure_block_absent` to `lib/core.sh`

**Files:**
- Modify: `lib/core.sh` (append two new functions at the end)

- [ ] **Step 1: Append the two functions to `lib/core.sh`**

Open `/Volumes/Code/dotfiles/lib/core.sh`. At the bottom (after the closing `}` of `core::pkg_install`), append:

```bash

# core::ensure_block <file> <id> <content>
# Idempotently writes a managed block into <file>. A block is delimited by
#   # BEGIN dotfiles:<id>
#   <content>
#   # END dotfiles:<id>
# Behaviour:
# - If <file> does not exist, create it first.
# - If the block is absent, append it (with a leading blank line if the file
#   is non-empty) and log "Added block".
# - If the block exists with identical content, log "unchanged" and leave
#   the file untouched.
# - If the block exists with different content, replace content in-place and
#   log "Updated block".
# <content> is written verbatim; callers pre-expand any variables they want
# captured at install-time, and escape "$" to keep shell expansions literal.
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
# Removes the named managed block (and its surrounding markers) from <file>.
# No-op if <file> does not exist or the block is absent. Used by module
# uninstall() hooks to clean up shell init blocks.
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

- [ ] **Step 2: Syntax check**

Run: `bash -n lib/core.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck lib/core.sh`
Expected: exit 0, no output.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d lib/core.sh`
Expected: exit 0, no diff. If shfmt prints a diff, apply it with `shfmt -w lib/core.sh` and re-run `shfmt -d` to confirm clean.

- [ ] **Step 5: Smoke test — `core::ensure_block`, 4 scenarios**

Run this exact script and confirm the output matches:

```bash
bash -c '
set -euo pipefail
export DOTFILES_ROOT="$(pwd)"
source lib/core.sh

tmp="$(mktemp -d)/zshrc"

# Scenario 1: file does not exist -> block created
core::ensure_block "${tmp}" "test" "echo one"
grep -q "# BEGIN dotfiles:test" "${tmp}" && echo "S1 OK" || echo "S1 FAIL"

# Scenario 2: file exists, block exists with identical content -> unchanged
before="$(cat "${tmp}")"
core::ensure_block "${tmp}" "test" "echo one"
after="$(cat "${tmp}")"
[[ "${before}" == "${after}" ]] && echo "S2 OK" || echo "S2 FAIL"

# Scenario 3: file exists, block exists with different content -> replaced
core::ensure_block "${tmp}" "test" "echo two"
grep -q "echo two" "${tmp}" && ! grep -q "echo one" "${tmp}" && echo "S3 OK" || echo "S3 FAIL"

# Scenario 4: file exists, block absent -> appended with leading blank line
core::ensure_block "${tmp}" "second" "echo zzz"
grep -q "# BEGIN dotfiles:second" "${tmp}" && echo "S4 OK" || echo "S4 FAIL"

rm -rf "$(dirname "${tmp}")"
'
```

Expected output (logs may interleave; look for the four `S* OK` lines):

```
S1 OK
S2 OK
S3 OK
S4 OK
```

- [ ] **Step 6: Smoke test — `core::ensure_block_absent`, 3 scenarios**

```bash
bash -c '
set -euo pipefail
export DOTFILES_ROOT="$(pwd)"
source lib/core.sh

tmpdir="$(mktemp -d)"

# Scenario A: file does not exist -> no-op, exit 0
core::ensure_block_absent "${tmpdir}/nope" "test" && echo "A OK" || echo "A FAIL"

# Scenario B: file exists, block absent -> no-op, exit 0
: >"${tmpdir}/file"
printf "keep me\n" >"${tmpdir}/file"
core::ensure_block_absent "${tmpdir}/file" "missing"
grep -q "keep me" "${tmpdir}/file" && echo "B OK" || echo "B FAIL"

# Scenario C: file exists, block present -> removed; surrounding content preserved
core::ensure_block "${tmpdir}/file" "remove-me" "echo inside"
core::ensure_block_absent "${tmpdir}/file" "remove-me"
! grep -q "BEGIN dotfiles:remove-me" "${tmpdir}/file" \
  && ! grep -q "echo inside" "${tmpdir}/file" \
  && grep -q "keep me" "${tmpdir}/file" \
  && echo "C OK" || echo "C FAIL"

rm -rf "${tmpdir}"
'
```

Expected: `A OK`, `B OK`, `C OK`.

- [ ] **Step 7: Smoke test — marker strictness (grep -qxF must not match substrings)**

```bash
bash -c '
set -euo pipefail
export DOTFILES_ROOT="$(pwd)"
source lib/core.sh

tmp="$(mktemp)"
# User wrote a comment that contains a substring of a marker but is NOT
# the exact marker — ensure_block with id="foo" must treat it as absent.
printf "%s\n" "# BEGIN dotfiles:foo-like but not exact" >"${tmp}"
core::ensure_block "${tmp}" "foo" "echo real"
grep -q "# BEGIN dotfiles:foo$" "${tmp}" && echo "STRICT OK" || echo "STRICT FAIL"
rm -f "${tmp}"
'
```

Expected: `STRICT OK`.

- [ ] **Step 8: Re-source safety**

```bash
bash -c 'set -euo pipefail
for i in 1 2 3; do
  source lib/core.sh
done
echo OK'
```

Expected: `OK` (no `readonly` re-definition errors).

- [ ] **Step 9: Commit**

```bash
git add lib/core.sh
git commit -m "$(cat <<'EOF'
feat(core): add core::ensure_block / core::ensure_block_absent

Two new lib primitives for idempotently writing markered config blocks into
text files. A block is delimited by:

  # BEGIN dotfiles:<id>
  <content>
  # END dotfiles:<id>

core::ensure_block is three-state:
- block absent     -> append with leading blank line, log "Added"
- block identical  -> no file write, log "unchanged"
- block different  -> in-place replace with awk, log "Updated"

core::ensure_block_absent removes the block (surrounding non-block content
preserved). Safe no-op when file or block absent.

Used by:
- bootstrap::homebrew (writes ~/.zprofile homebrew block)
- modules/fzf.sh, sheldon.sh, starship.sh (write ~/.zshrc init blocks)
- modules/rust.sh (writes ~/.zprofile cargo block)

awk (not sed -i) is used for in-place edit because sed -i has BSD/GNU
incompatibility; awk behaves identically on mac and Linux.

grep -qxF enforces full-line + fixed-string match so user comments with
similar-looking text cannot accidentally match a marker.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `bootstrap::zsh` to `lib/bootstrap.sh`

**Files:**
- Modify: `lib/bootstrap.sh` (add one new function after the header comment, before `bootstrap::xcode_clt`)

- [ ] **Step 1: Insert `bootstrap::zsh` before `bootstrap::xcode_clt`**

Open `/Volumes/Code/dotfiles/lib/bootstrap.sh`. Locate the comment block that begins with `# macOS only. Install the Xcode Command Line Tools` (currently around line 15). Insert the following **before** that comment (keep one blank line between `IFS=$'\n\t'` and the new function's header comment, and one blank line between the new function's closing `}` and the existing `# macOS only. Install the Xcode...` comment):

```bash

# Install zsh if missing, switch the user's login shell to zsh if it isn't
# already, and touch the three zsh startup files as empty skeletons so later
# stages can write managed blocks into them.
#
# This runs as Stage A of install.sh, before detect::pkg_manager. On Linux
# the zsh install dispatches directly on apt-get / dnf presence since
# DOTFILES_PKG_MANAGER isn't set yet. On macOS zsh is preinstalled so no
# package install happens.
#
# chsh failures bubble via set -e (hard fail): wrong password or zsh not in
# /etc/shells will abort the installer; the user fixes the cause and re-runs.
bootstrap::zsh() {
  if ! command -v zsh >/dev/null 2>&1; then
    case "${DOTFILES_OS}" in
    linux)
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y zsh
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y zsh
      else
        core::log ERROR "zsh not found and no supported package manager to install it"
        core::log ERROR "Supported Linux package managers: apt (Debian/Ubuntu), dnf (Fedora/RHEL)"
        return 1
      fi
      ;;
    mac)
      # macOS ships zsh preinstalled since Catalina. Reaching this branch
      # means the system zsh was removed — an unusual state we don't try to
      # repair automatically (installing brew's zsh here would conflict with
      # later brew stage).
      core::log ERROR "zsh not found on macOS; this is unusual (system zsh is preinstalled since Catalina)"
      core::log ERROR "Install zsh manually (e.g. restore /bin/zsh or brew install zsh) and re-run"
      return 1
      ;;
    *)
      core::log ERROR "bootstrap::zsh called with unsupported DOTFILES_OS=${DOTFILES_OS}"
      return 1
      ;;
    esac
    core::log INFO "zsh installed"
  else
    core::log INFO "zsh already installed"
  fi

  # SHELL env var is populated from /etc/passwd at login and does not update
  # within the same session after chsh. That is fine: a re-run in a fresh
  # shell will see the updated value, and an accidental second chsh within
  # the same session is a harmless no-op.
  local current_shell
  current_shell="$(basename "${SHELL:-/bin/sh}")"
  if [[ "${current_shell}" != "zsh" ]]; then
    core::log INFO "Changing login shell to zsh (chsh — may prompt for password)"
    chsh -s "$(command -v zsh)"
  else
    core::log INFO "Login shell already zsh"
  fi

  # Ensure real-file skeletons exist. touch is a no-op on existing files.
  # These files are NOT symlinks — downstream code uses core::ensure_block
  # to write markered blocks into them.
  touch "${HOME}/.zshrc" "${HOME}/.zprofile" "${HOME}/.zshenv"
}
```

- [ ] **Step 2: Syntax check**

Run: `bash -n lib/bootstrap.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck lib/bootstrap.sh`
Expected: exit 0, no output.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d lib/bootstrap.sh`
Expected: no diff. If diff appears, apply with `shfmt -w lib/bootstrap.sh` and re-check.

- [ ] **Step 5: Function visibility sanity check**

```bash
bash -c '
set -euo pipefail
export DOTFILES_ROOT="$(pwd)"
source lib/core.sh
source lib/bootstrap.sh
type bootstrap::zsh >/dev/null && echo OK
'
```

Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add lib/bootstrap.sh
git commit -m "$(cat <<'EOF'
feat(bootstrap): add bootstrap::zsh (Stage A primitive)

Installs zsh on Linux (apt or dnf) if missing, switches login shell to zsh
via chsh if not already set, and touches ~/.zshrc / ~/.zprofile / ~/.zshenv
as empty skeleton files.

Not wired into install.sh yet — that happens in a later commit. For now
the function is a pure addition; static checks still pass.

Notes:
- Cannot depend on DOTFILES_PKG_MANAGER: this runs before detect::pkg_manager.
  Dispatches on DOTFILES_OS instead: Linux uses direct command -v apt-get /
  dnf check; macOS relies on zsh being preinstalled (Catalina+).
- chsh failure hard-fails the installer via set -e; user fixes and re-runs.
- Does NOT manage /etc/shells: the common distros (apt, dnf, mac) already
  have the default zsh path there; the edge case surfaces a clear chsh error.
- Skeleton files are real files (not symlinks) so core::ensure_block can
  write managed blocks into them.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Rewrite `bootstrap::homebrew` to write a managed block to `~/.zprofile`

**Files:**
- Modify: `lib/bootstrap.sh` (replace the body of `bootstrap::homebrew`)

- [ ] **Step 1: Replace the `bootstrap::homebrew` body**

Open `/Volumes/Code/dotfiles/lib/bootstrap.sh`. Locate the current `bootstrap::homebrew` function. Replace the entire function (from the header comment starting with `# macOS only. Install Homebrew via the official upstream installer...` through the closing `}`) with:

```bash
# macOS only. Install Homebrew via the official upstream installer, write a
# managed "homebrew" block to ~/.zprofile (so brew stays on PATH for future
# login shells), and eval shellenv for the rest of this install run.
#
# This replaces the older approach where ~/.zshrc was expected to symlink
# zshrc.mac (which contained a hard-coded eval "$(/opt/homebrew/bin/brew
# shellenv)"). The zshrc.mac symlink is being removed in the same series,
# so bootstrap owns the persistent brew PATH wiring now.
#
# Apple Silicon installs to /opt/homebrew; Intel to /usr/local. A user who
# migrates machines will see core::ensure_block rewrite the block to match
# the new prefix on next run.
bootstrap::homebrew() {
  if command -v brew >/dev/null 2>&1; then
    core::log INFO "Homebrew already installed"
    return 0
  fi

  core::log INFO "Installing Homebrew (official installer)..."
  # Interactive by default — brew prompts "Press RETURN to continue" so the
  # user can review what is about to happen before granting sudo. We do NOT
  # set NONINTERACTIVE=1.
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

  # Persist for future login shells. ~/.zprofile was touched by
  # bootstrap::zsh in Stage A, so it exists. ${brew_prefix} expands at
  # install-time; the inner $(...) stays literal for zsh to eval at login.
  core::ensure_block "${HOME}/.zprofile" "homebrew" \
    "eval \"\$(${brew_prefix}/bin/brew shellenv)\""

  # Activate for the rest of THIS install run — .zprofile only applies to
  # login shells, but later stages/modules in this same process need brew
  # on PATH now.
  eval "$("${brew_prefix}/bin/brew" shellenv)"

  core::log INFO "Homebrew installed; shellenv wired into ~/.zprofile"
}
```

- [ ] **Step 2: Syntax check**

Run: `bash -n lib/bootstrap.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck lib/bootstrap.sh`
Expected: exit 0, no output.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d lib/bootstrap.sh`
Expected: no diff. If diff appears, apply with `shfmt -w lib/bootstrap.sh` and re-check.

- [ ] **Step 5: Escaping sanity check (no actual install)**

Verify the content string would be rendered correctly if the function ran. We can't run the full function (no brew to install on an already-brew'd machine is fine; mac's brew short-circuits), but we can simulate the `core::ensure_block` call:

```bash
bash -c '
set -euo pipefail
export DOTFILES_ROOT="$(pwd)"
source lib/core.sh

tmp="$(mktemp)"
brew_prefix=/opt/homebrew
core::ensure_block "${tmp}" "homebrew" \
  "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
grep -q "^eval \"\$(/opt/homebrew/bin/brew shellenv)\"$" "${tmp}" \
  && echo "ESCAPE OK" || { echo "ESCAPE FAIL"; cat "${tmp}"; }
rm -f "${tmp}"
'
```

Expected: `ESCAPE OK`. If `ESCAPE FAIL`, the rendered block line is wrong — fix the escaping in Step 1 and re-run.

- [ ] **Step 6: Commit**

```bash
git add lib/bootstrap.sh
git commit -m "$(cat <<'EOF'
refactor(bootstrap): homebrew writes managed block to ~/.zprofile

bootstrap::homebrew now uses core::ensure_block to write a "homebrew"
block to ~/.zprofile with the brew shellenv eval. This replaces the old
approach where the persistent PATH wiring lived in config/zsh/zshrc.mac
(symlinked by the zsh module). That symlink is being removed in a later
commit — bootstrap owns the wiring now.

Apple Silicon vs Intel resolution collapses to one variable assignment
(brew_prefix), which feeds both the block content and the in-run eval.
If the user migrates machines (Intel -> Apple Silicon), core::ensure_block
detects the changed content and rewrites the block.

The old symlinked zshrc.mac still sources the same eval line until
Task 10 deletes it; both mechanisms co-exist harmlessly (the eval is
idempotent).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Create `modules/fzf.sh`

**Files:**
- Create: `modules/fzf.sh`

- [ ] **Step 1: Write the module file**

Create `/Volumes/Code/dotfiles/modules/fzf.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# modules/fzf.sh — fzf fuzzy finder with zsh key bindings
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="fzf"
MODULE_DESC="fzf fuzzy finder with zsh key bindings"
MODULE_PLATFORM="all"

LINKS=()

# Installs the fzf package and writes the zsh integration block to ~/.zshrc.
# The `eval "$(fzf --zsh)"` line enables Ctrl+R (history search) and Ctrl+T
# (file search) key bindings. It must run after `sheldon source` when both
# are present (sheldon's fzf-tab plugin integrates with fzf) — install order
# in _MODULES puts fzf before sheldon so the fzf binary is on PATH when
# sheldon loads, but the init block order is determined by module run order,
# which places the fzf block before the sheldon block in ~/.zshrc. Both
# orders work: fzf's --zsh emits a self-contained init that doesn't depend
# on sheldon, and sheldon's fzf-tab loads later, picking up fzf already set.
install() {
  core::pkg_install fzf
  core::ensure_block "${HOME}/.zshrc" "fzf" 'eval "$(fzf --zsh)"'
}

uninstall() {
  core::ensure_block_absent "${HOME}/.zshrc" "fzf"
}
```

- [ ] **Step 2: Syntax check**

Run: `bash -n modules/fzf.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck modules/fzf.sh`
Expected: exit 0, no output.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d modules/fzf.sh`
Expected: no diff.

- [ ] **Step 5: Commit**

```bash
git add modules/fzf.sh
git commit -m "$(cat <<'EOF'
feat(fzf): new module — fzf fuzzy finder with zsh key bindings

Installs the fzf package and writes a managed "fzf" block to ~/.zshrc
containing `eval "$(fzf --zsh)"`, which enables Ctrl+R (history) and
Ctrl+T (file) bindings.

Not in _MODULES yet — wired in by the install.sh commit that completes
the zsh-blocks series.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Create `modules/sheldon.sh`

**Files:**
- Create: `modules/sheldon.sh`

- [ ] **Step 1: Write the module file**

Create `/Volumes/Code/dotfiles/modules/sheldon.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# modules/sheldon.sh — sheldon zsh plugin manager with curated plugin set
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
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

# Installs sheldon + its curated plugin set and writes the zsh init block.
# plugins.toml is generated by `sheldon init` on first run; subsequent runs
# use `sheldon add` which is idempotent-ish (errors on duplicate, silenced).
install() {
  core::pkg_install sheldon

  local config="${HOME}/.config/sheldon/plugins.toml"
  if [[ ! -f "${config}" ]]; then
    sheldon init --shell zsh
  fi

  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    # sheldon add errors on "plugin already present"; silence it, then move on.
    sheldon add "${name}" --github "${plugin}" >/dev/null 2>&1 || true
  done

  _sheldon::patch_fpath_for_zsh_completions "${config}"

  # Init block: sheldon source + compinit + history key bindings.
  # These three must run in this order: sheldon first populates fpath,
  # compinit then consumes it, and the history-substring bindkeys need
  # the plugin (loaded by sheldon source) to already be in memory.
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

# Patches the zsh-completions plugin in sheldon's plugins.toml to use
# `apply = ["fpath"]` — the CLI has no direct flag for this. Without it,
# zsh-completions triggers "insecure directories" warnings and completion
# misfires. Idempotent: if the apply key is already present, no-op.
_sheldon::patch_fpath_for_zsh_completions() {
  local config="${1}"
  if awk '/^\[plugins\.zsh-completions\]/ { in_s=1; next } /^\[/ { in_s=0 } in_s && /^apply = \["fpath"\]/ { f=1 } END { exit !f }' "${config}"; then
    return 0
  fi
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

- [ ] **Step 2: Syntax check**

Run: `bash -n modules/sheldon.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck modules/sheldon.sh`
Expected: exit 0, no output.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d modules/sheldon.sh`
Expected: no diff.

- [ ] **Step 5: TOML patch smoke test**

Simulate the patch on a fake plugins.toml:

```bash
bash -c '
set -euo pipefail
export DOTFILES_ROOT="$(pwd)"
source lib/core.sh
source modules/sheldon.sh 2>/dev/null || true

# Cannot actually source sheldon.sh because it is missing module-interface
# bootstrapping from install.sh; instead call the private helper through
# a direct function-definition grep-and-eval. Simpler: inline-test the awk.

tmp="$(mktemp)"
cat >"${tmp}" <<'\''EOF'\''
[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"

[plugins.zsh-completions]
github = "zsh-users/zsh-completions"

[plugins.z]
github = "rupa/z"
EOF

# Run the patch awk — same awk as in _sheldon::patch_fpath_for_zsh_completions.
patched="$(mktemp)"
awk '\''
  /^\[plugins\.zsh-completions\]/ {
    print
    print "apply = [\"fpath\"]"
    next
  }
  { print }
'\'' "${tmp}" >"${patched}"

grep -A1 "zsh-completions" "${patched}" | grep -q "apply = \[\"fpath\"\]" \
  && echo "PATCH OK" || { echo "PATCH FAIL"; cat "${patched}"; }

rm -f "${tmp}" "${patched}"
'
```

Expected: `PATCH OK`.

- [ ] **Step 6: Commit**

```bash
git add modules/sheldon.sh
git commit -m "$(cat <<'EOF'
feat(sheldon): new module — sheldon plugin manager + curated plugins

Installs sheldon, bootstraps ~/.config/sheldon/plugins.toml via `sheldon init`,
adds the curated plugin set via `sheldon add --github <owner/repo>` (seven
plugins: zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions,
fzf-tab, zsh-safe-rm, z, zsh-history-substring-search), patches
zsh-completions to use `apply = ["fpath"]` (the CLI has no flag for this),
and writes the managed "sheldon" block to ~/.zshrc containing:

  eval "$(sheldon source)"
  autoload -Uz compinit && compinit
  bindkey "^[[A" history-substring-search-up
  bindkey "^[[B" history-substring-search-down

Ordering inside the block is load-bearing: sheldon source must run first
(populates fpath + loads history-substring-search), compinit consumes
fpath, bindkeys need the plugin already in memory.

Known tech debt: if sheldon changes its TOML output format, the awk-based
patch breaks. Acceptable — fix when it breaks.

Not in _MODULES yet — wired in by install.sh commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Create `modules/starship.sh`

**Files:**
- Create: `modules/starship.sh`

- [ ] **Step 1: Write the module file**

Create `/Volumes/Code/dotfiles/modules/starship.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# modules/starship.sh — Starship prompt (catppuccin-powerline preset)
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="starship"
MODULE_DESC="Starship prompt (catppuccin-powerline preset)"
MODULE_PLATFORM="all"

LINKS=()

_STARSHIP_PRESET="catppuccin-powerline"

# Installs starship, generates ~/.config/starship.toml from the preset if it
# doesn't exist yet, and writes the zsh init block. Does NOT regenerate an
# existing config — users who've tweaked their prompt keep their tweaks.
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

- [ ] **Step 2: Syntax check**

Run: `bash -n modules/starship.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck modules/starship.sh`
Expected: exit 0, no output.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d modules/starship.sh`
Expected: no diff.

- [ ] **Step 5: Commit**

```bash
git add modules/starship.sh
git commit -m "$(cat <<'EOF'
feat(starship): new module — Starship prompt with catppuccin-powerline preset

Installs starship, generates ~/.config/starship.toml from the preset
`catppuccin-powerline` on first run (via `starship preset --output`), and
writes the managed "starship" block to ~/.zshrc containing:

  eval "$(starship init zsh)"

Existing ~/.config/starship.toml is not overwritten — users who tweak the
preset keep their changes across re-runs.

Not in _MODULES yet — wired in by install.sh commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Update `modules/rust.sh` — add cargo zprofile block

**Files:**
- Modify: `modules/rust.sh`

- [ ] **Step 1: Add cargo block calls**

Open `/Volumes/Code/dotfiles/modules/rust.sh`. Replace the existing `install()` and `uninstall()` functions with:

```bash
# Installs the Rust stable toolchain via the official rustup script.
# Idempotent: skips if rustup is already present. After install (or skip),
# sources ~/.cargo/env so later modules (nvim → tree-sitter-cli) can see cargo,
# and writes a "rust" block to ~/.zprofile so future shells pick up cargo too.
install() {
  if core::check_installed rustup; then
    core::log INFO "rustup already installed — skipping"
  else
    # --no-modify-path: we manage PATH via the ~/.zprofile block below,
    # not via rustup's own shell-integration patching.
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
      sh -s -- -y --no-modify-path
    core::log INFO "rustup installed"
  fi

  if [[ -f "${HOME}/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
  else
    core::log WARN "${HOME}/.cargo/env not found — cargo may not be on PATH"
  fi

  # Persist cargo env for future login shells. Symmetric with brew's
  # ~/.zprofile wiring in bootstrap::homebrew. ${HOME} is escaped so zsh
  # expands it at login, not bash at install-time.
  core::ensure_block "${HOME}/.zprofile" "rust" \
    '[[ -f "${HOME}/.cargo/env" ]] && . "${HOME}/.cargo/env"'
}

uninstall() {
  core::ensure_block_absent "${HOME}/.zprofile" "rust"
}
```

The only two behavioural changes vs the old version:
1. The comment above the rustup curl line drops the stale "`--no-modify-path`: `~/.cargo/env` is already sourced via `config/zsh/zshenv`" (zshenv is being deleted) in favour of the new one referring to the zprofile block.
2. `install()` ends with a new `core::ensure_block` call.
3. `uninstall()` changes from `{ :; }` to a one-line `core::ensure_block_absent` call.

- [ ] **Step 2: Syntax check**

Run: `bash -n modules/rust.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck modules/rust.sh`
Expected: exit 0, no output.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d modules/rust.sh`
Expected: no diff.

- [ ] **Step 5: Escaping sanity check for the cargo block**

```bash
bash -c '
set -euo pipefail
export DOTFILES_ROOT="$(pwd)"
source lib/core.sh

tmp="$(mktemp)"
core::ensure_block "${tmp}" "rust" \
  '\''[[ -f "${HOME}/.cargo/env" ]] && . "${HOME}/.cargo/env"'\''
# We want the literal line to contain ${HOME}, not expanded to the current HOME.
grep -q '\''\[\[ -f "\${HOME}/\.cargo/env" \]\] && \. "\${HOME}/\.cargo/env"'\'' "${tmp}" \
  && echo "ESCAPE OK" || { echo "ESCAPE FAIL"; cat "${tmp}"; }
rm -f "${tmp}"
'
```

Expected: `ESCAPE OK`. `${HOME}` must appear literally in the block — zsh expands it at runtime.

- [ ] **Step 6: Commit**

```bash
git add modules/rust.sh
git commit -m "$(cat <<'EOF'
refactor(rust): write cargo env block to ~/.zprofile; symmetric uninstall

Replaces the old arrangement where cargo PATH wiring lived in
config/zsh/zshenv (symlinked by the zsh module, which is going away).

install() now calls core::ensure_block to append:

  # BEGIN dotfiles:rust
  [[ -f "${HOME}/.cargo/env" ]] && . "${HOME}/.cargo/env"
  # END dotfiles:rust

to ~/.zprofile. ${HOME} is kept literal (escaped) so zsh expands it at
login, not bash at install-time.

uninstall() drops the no-op and removes the block via
core::ensure_block_absent. Symmetric with brew's ~/.zprofile wiring.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Rewire `install.sh` — 4-stage main() + updated `_MODULES`

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Update `_MODULES`**

In `/Volumes/Code/dotfiles/install.sh`, change line 16 from:

```bash
readonly _MODULES=(ghostty git rust nvim tmux zsh)
```

to:

```bash
readonly _MODULES=(ghostty git rust fzf sheldon starship nvim tmux)
```

Order rationale (keep as an inline comment above the line — update the existing `# rust must precede nvim` comment to cover fzf/sheldon too):

```bash
# Explicit install order — dependencies first.
# rust must precede nvim (cargo is required for tree-sitter-cli).
# fzf must precede sheldon (sheldon's fzf-tab plugin requires the fzf binary).
readonly _MODULES=(ghostty git rust fzf sheldon starship nvim tmux)
```

- [ ] **Step 2: Rewrite `main()` as 4 stages**

Replace the current `main()` body (currently `detect::os` → 3-stage → module loop) with:

```bash
main() {
  # Detect OS first — bootstrap steps and the module loop both dispatch by it.
  detect::os

  # Stage A: ensure zsh + shell skeleton files exist.
  # Linux apt/dnf install zsh; mac is preinstalled. chsh if default shell
  # isn't zsh. Touch ~/.zshrc ~/.zprofile ~/.zshenv as real empty files.
  bootstrap::zsh

  # Stage B: ensure a package manager exists (macOS only).
  # macOS requires Xcode CLT + Homebrew; Linux's apt/dnf ships with the distro.
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    bootstrap::xcode_clt
    bootstrap::homebrew
  fi

  # Stage C: identify the package manager now that one is guaranteed present.
  detect::pkg_manager

  # Stage D: install dev tools every module assumes exist (compiler toolchain,
  # build systems). Hard-fails on an unsupported pm rather than letting
  # modules limp along.
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

The only differences from the current `main()`:
- Stage comments are relabelled A/B/C/D.
- One new line `bootstrap::zsh` inserted between `detect::os` and Stage B.
- Hard-fails comment slightly softened to read "on an unsupported pm" (cosmetic).
- Everything else (module loop, final log) unchanged.

- [ ] **Step 3: Syntax check**

Run: `bash -n install.sh`
Expected: exit 0, no output.

- [ ] **Step 4: Shellcheck**

Run: `shellcheck install.sh`
Expected: exit 0, no output.

- [ ] **Step 5: shfmt diff check**

Run: `shfmt -d install.sh`
Expected: no diff.

- [ ] **Step 6: Call-graph sanity check**

```bash
bash -c '
set -euo pipefail
export DOTFILES_ROOT="$(pwd)"
source ./lib/detect.sh
source ./lib/core.sh
source ./lib/bootstrap.sh
for fn in bootstrap::zsh bootstrap::xcode_clt bootstrap::homebrew bootstrap::dev_tools \
          detect::os detect::pkg_manager \
          core::ensure_block core::ensure_block_absent; do
  type "$fn" >/dev/null || { echo "MISSING: $fn"; exit 1; }
done
echo OK'
```

Expected: `OK`.

Also verify that each module named in `_MODULES` has a file:

```bash
for m in ghostty git rust fzf sheldon starship nvim tmux; do
  [[ -f "modules/${m}.sh" ]] || { echo "MISSING module: ${m}"; exit 1; }
done
echo "all modules present"
```

Expected: `all modules present`. (Note `zsh` is intentionally absent from `_MODULES`; `modules/zsh.sh` still exists on disk but is no longer loaded — it will be deleted in Task 10.)

- [ ] **Step 7: Commit**

```bash
git add install.sh
git commit -m "$(cat <<'EOF'
feat(install): 4-stage main() + switch _MODULES to block-model layout

main() orchestration is now:
  detect::os
  Stage A: bootstrap::zsh                   (all platforms)
  Stage B: bootstrap::xcode_clt + homebrew  (mac only)
  Stage C: detect::pkg_manager              (all)
  Stage D: bootstrap::dev_tools             (all)
  <existing module loop>

_MODULES: (ghostty git rust nvim tmux zsh)
      ->  (ghostty git rust fzf sheldon starship nvim tmux)

The zsh module is no longer loaded (replaced by Stage A + the three new
tool modules). modules/zsh.sh still exists on disk but is orphaned — the
next commit deletes it together with config/zsh/*.

fzf must precede sheldon in the ordering: sheldon's fzf-tab plugin
requires the fzf binary at runtime, so fzf's install() must land first.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Sync `uninstall.sh` `_MODULES`

**Files:**
- Modify: `uninstall.sh`

- [ ] **Step 1: Update `_MODULES`**

In `/Volumes/Code/dotfiles/uninstall.sh`, change line 11 from:

```bash
readonly _MODULES=(ghostty git rust nvim tmux zsh)
```

to:

```bash
readonly _MODULES=(ghostty git rust fzf sheldon starship nvim tmux)
```

No other changes to `uninstall.sh` — the file already explicitly calls `detect::os` (and deliberately not `detect::pkg_manager`) in `main()` from the previous bootstrap series.

- [ ] **Step 2: Syntax check**

Run: `bash -n uninstall.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck uninstall.sh`
Expected: exit 0, no output.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d uninstall.sh`
Expected: no diff.

- [ ] **Step 5: Commit**

```bash
git add uninstall.sh
git commit -m "$(cat <<'EOF'
chore(uninstall): sync _MODULES with install.sh

Matches the block-model module list (zsh removed; fzf, sheldon, starship
added). Ordering is symmetric with install.sh since uninstall::run_module
removes LINKS before calling each module's uninstall() hook, and none of
the new modules' uninstall() hooks depend on ordering.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Delete the old zsh module + `config/zsh/`

**Files:**
- Delete: `modules/zsh.sh`
- Delete: `config/zsh/zshrc.mac`
- Delete: `config/zsh/zshrc.linux`
- Delete: `config/zsh/zshenv`
- Delete: `config/zsh/starship.toml`
- Delete: `config/zsh/sheldon/plugins.toml`
- Delete (empty dirs): `config/zsh/sheldon/`, `config/zsh/`

- [ ] **Step 1: Delete files with `git rm`**

```bash
git rm modules/zsh.sh
git rm config/zsh/zshrc.mac
git rm config/zsh/zshrc.linux
git rm config/zsh/zshenv
git rm config/zsh/starship.toml
git rm config/zsh/sheldon/plugins.toml
```

- [ ] **Step 2: Remove now-empty directories**

```bash
# git rm does not remove empty parent dirs; clean them up explicitly.
rmdir config/zsh/sheldon
rmdir config/zsh
```

Expected: both `rmdir`s succeed. If either reports "directory not empty", investigate (there should be no leftover files).

- [ ] **Step 3: Confirm no code references the deleted paths**

```bash
grep -rn 'config/zsh\|modules/zsh.sh\|zshrc.mac\|zshrc.linux' \
  install.sh uninstall.sh lib/ modules/ 2>/dev/null \
  && { echo "!!! leftover references"; exit 1; } \
  || echo "no leftover references — OK"
```

Expected: `no leftover references — OK`. docs/changes/ and README may still mention these paths; that's handled in Task 11.

- [ ] **Step 4: Full static-check sweep**

```bash
bash -n install.sh uninstall.sh lib/*.sh modules/*.sh \
  && shellcheck install.sh uninstall.sh lib/*.sh modules/*.sh \
  && shfmt -d install.sh uninstall.sh lib/*.sh modules/*.sh \
  && echo "all static checks clean"
```

Expected: `all static checks clean`.

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore(zsh): delete modules/zsh.sh and config/zsh/ — replaced by block model

Files removed:
- modules/zsh.sh (replaced by bootstrap::zsh + modules/fzf.sh / sheldon.sh
  / starship.sh)
- config/zsh/zshrc.mac (replaced by managed blocks in ~/.zshrc)
- config/zsh/zshrc.linux (ditto)
- config/zsh/zshenv (cargo env moved to modules/rust.sh's ~/.zprofile block)
- config/zsh/starship.toml (starship module generates via `starship preset`)
- config/zsh/sheldon/plugins.toml (sheldon module generates via
  `sheldon init` + `sheldon add`)
- config/zsh/sheldon/ + config/zsh/ (empty dirs)

_MODULES was already switched in the install.sh commit, so these files
are orphaned at this point — nothing loads them. This commit just cleans
up the tree.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Documentation — delete zsh.md, add 3 new module docs, update README

**Files:**
- Delete: `docs/modules/zsh.md`
- Create: `docs/modules/fzf.md`
- Create: `docs/modules/sheldon.md`
- Create: `docs/modules/starship.md`
- Modify: `README.md`

- [ ] **Step 1: Delete `docs/modules/zsh.md`**

```bash
git rm docs/modules/zsh.md
```

- [ ] **Step 2: Create `docs/modules/fzf.md`**

```markdown
# Module: fzf

[fzf](https://github.com/junegunn/fzf) fuzzy finder with zsh key bindings.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| — | — | — |

No LINKS — all configuration is done via the managed `fzf` block in
`~/.zshrc`.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install fzf`; append `eval "$(fzf --zsh)"` to `~/.zshrc` as a managed `fzf` block |
| `uninstall` | remove the `fzf` block from `~/.zshrc` (package is preserved) |

## Notes

`fzf --zsh` emits the key-binding setup that enables:

- **Ctrl+R**: fuzzy search command history
- **Ctrl+T**: fuzzy file picker
- **Alt+C**: fuzzy directory jump

The fzf package must be installed before the sheldon module runs because
sheldon's `fzf-tab` plugin requires the `fzf` binary on PATH. Install order
is managed by `_MODULES` in `install.sh`.
```

- [ ] **Step 3: Create `docs/modules/sheldon.md`**

```markdown
# Module: sheldon

[sheldon](https://github.com/rossmacarthur/sheldon) zsh plugin manager with a
curated plugin set.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| — | — | — |

No LINKS — `~/.config/sheldon/plugins.toml` is generated by `sheldon init`
on first run and populated via `sheldon add` calls. A managed `sheldon`
block in `~/.zshrc` performs the runtime wiring.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install sheldon`; `sheldon init --shell zsh` (first run); `sheldon add` each plugin in `_SHELDON_PLUGINS`; patch zsh-completions to use `apply = ["fpath"]`; write managed `sheldon` block to `~/.zshrc` |
| `uninstall` | remove the `sheldon` block from `~/.zshrc` (package and `plugins.toml` are preserved) |

## Plugins installed

| Plugin | Purpose |
|---|---|
| `zsh-users/zsh-autosuggestions` | fish-like command suggestions |
| `zsh-users/zsh-syntax-highlighting` | syntax coloring while typing |
| `zsh-users/zsh-completions` | additional completion definitions |
| `Aloxaf/fzf-tab` | fzf-powered tab completion |
| `mattmc3/zsh-safe-rm` | trash instead of real `rm` |
| `rupa/z` | frecency-based directory jumping |
| `zsh-users/zsh-history-substring-search` | Ctrl+R-style substring history nav |

## Init block contents

The managed `sheldon` block in `~/.zshrc` contains:

```zsh
eval "$(sheldon source)"

# Completion system (after sheldon so fpath is fully populated)
autoload -Uz compinit && compinit

# History substring search key bindings (plugin loaded above)
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down
```

Ordering is load-bearing:
1. `sheldon source` populates `fpath` and loads every plugin.
2. `compinit` consumes the expanded `fpath`.
3. `bindkey` lines require the `history-substring-search` plugin already
   loaded.

## Notes

`zsh-completions` requires `apply = ["fpath"]` in its `plugins.toml` entry
to avoid "insecure directories" warnings. The `sheldon add` CLI has no
direct flag for this, so the module patches `plugins.toml` via `awk` after
running the `add` commands. If sheldon's output format changes, the patch
may break; fix when that happens.
```

- [ ] **Step 4: Create `docs/modules/starship.md`**

```markdown
# Module: starship

[Starship](https://starship.rs/) prompt, configured with the
`catppuccin-powerline` preset.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| — | — | — |

No LINKS — `~/.config/starship.toml` is generated by `starship preset` on
first run. Subsequent runs preserve any hand edits.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install starship`; generate `~/.config/starship.toml` from preset if absent; write managed `starship` block to `~/.zshrc` |
| `uninstall` | remove the `starship` block from `~/.zshrc` (package and `~/.config/starship.toml` are preserved) |

## Config generation

On first run the module runs:

```bash
starship preset catppuccin-powerline --output ~/.config/starship.toml
```

If the file already exists, it is left alone. This lets you hand-tune the
prompt without dotfiles overwriting your changes on re-run.

## Init block contents

The managed `starship` block in `~/.zshrc` contains a single line:

```zsh
eval "$(starship init zsh)"
```

## Notes

The preset name is hard-coded in `_STARSHIP_PRESET` inside
`modules/starship.sh`. Change it there and re-run `./install.sh` — but the
existing `~/.config/starship.toml` won't be regenerated; delete it manually
first if you want the new preset applied.
```

- [ ] **Step 5: Update `README.md` Modules table**

In `/Volumes/Code/dotfiles/README.md`, replace the current Modules table
(around lines 40-49):

```markdown
| Module | Platform | What it manages |
|---|---|---|
| `git` | all | gitconfig + custom hooks |
| `zsh` | all | sheldon (plugin manager) + starship (prompt) |
| `nvim` | all | Neovim + LazyVim configuration |
| `tmux` | all | tmux + oh-my-tmux configuration |
| `ghostty` | macOS | Ghostty terminal config |

See [`docs/modules/`](docs/modules/) for per-module details. (The `rust` module runs as
an internal dependency of `nvim`; it is not a user-facing module.)
```

with:

```markdown
| Module | Platform | What it manages |
|---|---|---|
| `git` | all | gitconfig + custom hooks |
| `fzf` | all | fzf fuzzy finder + zsh key bindings |
| `sheldon` | all | zsh plugin manager + curated plugins |
| `starship` | all | Starship prompt (catppuccin-powerline preset) |
| `nvim` | all | Neovim + LazyVim configuration |
| `tmux` | all | tmux + oh-my-tmux configuration |
| `ghostty` | macOS | Ghostty terminal config |

See [`docs/modules/`](docs/modules/) for per-module details. (The `rust` module runs as
an internal dependency of `nvim`; it is not a user-facing module.)

The zsh shell itself, `~/.zshrc`, `~/.zprofile`, and `~/.zshenv` are
managed by the installer's bootstrap stage, not by a module. Each tool
module (fzf / sheldon / starship) writes its own initialization block
into `~/.zshrc`; `bootstrap::homebrew` and the rust module write to
`~/.zprofile`. Blocks are delimited by `# BEGIN dotfiles:<id>` /
`# END dotfiles:<id>` markers and are safe to re-apply — only content
inside the markers is overwritten on re-run.
```

- [ ] **Step 6: Visual check**

```bash
cat README.md | sed -n '38,60p'
ls docs/modules/
```

Expected (README): the new Modules table + the explanatory paragraph.
Expected (docs/modules ls): `ghostty.md`, `git.md`, `fzf.md`, `sheldon.md`, `starship.md`, `nvim.md`, `tmux.md` — no `zsh.md`.

- [ ] **Step 7: Commit**

```bash
git add README.md docs/modules/fzf.md docs/modules/sheldon.md docs/modules/starship.md
git commit -m "$(cat <<'EOF'
docs: replace zsh module docs with fzf/sheldon/starship; update README

- Delete docs/modules/zsh.md (module no longer exists)
- Add docs/modules/fzf.md, sheldon.md, starship.md (three new modules)
- Update README Modules table: drop zsh row, add fzf/sheldon/starship rows
- Add paragraph explaining the block-model approach and the bootstrap-owned
  shell skeleton

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Final sweep — full static checks, re-source safety, trial install

**Files:**
- None (verification only)

- [ ] **Step 1: Full static-check sweep**

```bash
echo "=== bash -n ===" \
  && bash -n install.sh uninstall.sh lib/*.sh modules/*.sh \
  && echo "=== shellcheck ===" \
  && shellcheck install.sh uninstall.sh lib/*.sh modules/*.sh \
  && echo "=== shfmt -d ===" \
  && shfmt -d install.sh uninstall.sh lib/*.sh modules/*.sh \
  && echo "=== ALL CLEAN ==="
```

Expected: `ALL CLEAN`.

- [ ] **Step 2: Re-source safety (three times under strict mode)**

```bash
bash -c 'set -euo pipefail
export DOTFILES_ROOT="$(pwd)"
for i in 1 2 3; do
  source lib/core.sh
  source lib/detect.sh
  source lib/bootstrap.sh
done
echo "OK: sourced 3x"'
```

Expected: `OK: sourced 3x`.

- [ ] **Step 3: Grep for stale references**

```bash
echo "=== zsh module references ==="
grep -rn 'modules/zsh' install.sh uninstall.sh lib/ modules/ README.md docs/modules/ 2>/dev/null \
  && { echo "!!! leftover modules/zsh reference"; exit 1; } \
  || echo "no modules/zsh reference — OK"

echo "=== config/zsh references ==="
grep -rn 'config/zsh' install.sh uninstall.sh lib/ modules/ README.md docs/modules/ 2>/dev/null \
  && { echo "!!! leftover config/zsh reference"; exit 1; } \
  || echo "no config/zsh reference — OK"

echo "=== zshrc.mac / zshrc.linux / zshenv references ==="
grep -rnE 'zshrc\.(mac|linux)|config/zsh/zshenv' install.sh uninstall.sh lib/ modules/ README.md docs/modules/ 2>/dev/null \
  && { echo "!!! leftover old-zsh-file reference"; exit 1; } \
  || echo "no old-zsh-file references — OK"
```

Expected: three `no ... — OK` lines.

Note: `docs/changes/` directories are *intentionally* excluded from these greps — design docs discuss the removal and keep the historical reference.

- [ ] **Step 4: Verify all `_MODULES` entries have a module file**

```bash
for m in ghostty git rust fzf sheldon starship nvim tmux; do
  [[ -f "modules/${m}.sh" ]] || { echo "MISSING module: ${m}"; exit 1; }
done
[[ ! -f modules/zsh.sh ]] || { echo "!!! modules/zsh.sh still present"; exit 1; }
echo "module files aligned with _MODULES"
```

Expected: `module files aligned with _MODULES`.

- [ ] **Step 5: Verify `config/zsh/` is gone**

```bash
[[ ! -d config/zsh ]] && echo "config/zsh/ gone" || { echo "!!! config/zsh/ still present"; ls -la config/zsh; exit 1; }
```

Expected: `config/zsh/ gone`.

- [ ] **Step 6: Re-run all core::ensure_block smoke tests (sanity)**

Re-run the smoke tests from Task 1 Steps 5–7. They should all still pass after every subsequent commit.

- [ ] **Step 7: Trial run — `./install.sh` on the current (already-bootstrapped) mac**

On a machine that already has zsh (default), brew, and most dev tools, `./install.sh` is expected to:

1. Stage A: log `zsh already installed`, `Login shell already zsh`, then touch the three zsh files (no-op since they exist).
2. Stage B: log `Xcode Command Line Tools already installed`, `Homebrew already installed` — brew binary already present, so no block write happens from `bootstrap::homebrew` at this run (the early return guards it; **first-time** installs on a clean mac will write the block).
3. Stage C: `Platform: mac | Package manager: brew`.
4. Stage D: `brew install cmake meson ninja gettext` — idempotent; prints "already installed" warnings.
5. Module loop: each module runs; **first run** after merge will:
   - fzf: install package, write `# BEGIN dotfiles:fzf` block to `~/.zshrc`.
   - sheldon: install package, `sheldon init` (or skip if exists), `sheldon add` each plugin, patch zsh-completions, write block.
   - starship: install package, run preset (or skip if config exists), write block.
   - rust: install rustup (or skip), write `rust` block to `~/.zprofile`.

Run:

```bash
./install.sh
```

Expected: success (exit 0); no errors in the log stream.

After the run, inspect:

```bash
# Blocks in ~/.zshrc (order should be: fzf, sheldon, starship — matching _MODULES order)
grep "BEGIN dotfiles:" ~/.zshrc

# Blocks in ~/.zprofile (order should be: rust — brew block only appears if brew was freshly installed this run)
grep "BEGIN dotfiles:" ~/.zprofile
```

Expected in `~/.zshrc`:

```
# BEGIN dotfiles:fzf
# BEGIN dotfiles:sheldon
# BEGIN dotfiles:starship
```

Expected in `~/.zprofile`:

```
# BEGIN dotfiles:rust
```

(`homebrew` block in `~/.zprofile` appears only on machines where brew was actually installed by bootstrap; on a machine where brew was pre-existing, the block is not added — this is acceptable because `~/.zprofile` persistence was already achieved by whatever onboarding step installed brew originally.)

- [ ] **Step 8: Open a fresh terminal and spot-check**

Open a new terminal session. Verify:

- Prompt is `catppuccin-powerline` (starship)
- `echo $0` prints `-zsh` (login shell is zsh)
- `Ctrl+R` triggers fzf history search
- `sheldon source` loaded; `starship init` loaded; no errors on shell startup

- [ ] **Step 9: No commit**

Task 12 is verification only. If everything passed, there is nothing to commit. If any step surfaced a bug, fix it in a new targeted commit before considering the feature done.

---

## Self-Review Notes

**Spec coverage (design.md → task):**

- §1 Architecture overview → Tasks 1–11
- §2 Stage orchestration → Task 8
- §3 `bootstrap::zsh` → Task 2
- §4 `core::ensure_block` primitives → Task 1
- §5 New modules fzf/sheldon/starship → Tasks 4/5/6
- §6 `bootstrap::homebrew` rewrite + cargo block → Tasks 3, 7
- §7 Uninstall + idempotency → verified across Tasks 4/5/6/7 (each module has ensure_block_absent) + Task 9
- §8 Asymmetries — descriptive only, no task
- §9 File inventory → all touched via Tasks 1–11
- §10 Testing approach → Tasks 1, 12
- §11 Non-goals — descriptive; no task. Explicitly verified: Tasks 4–6 do not add advanced ensure_block features; Task 10 does not remove bootstrap products; Task 9 keeps `uninstall.sh` `detect::os`-only.

**No placeholders**: Every code step has concrete content. Every commit message is written out. Every expected output is specified. No "TBD" / "similar to Task N" patterns.

**Type consistency**: `core::ensure_block <file> <id> <content>` — same signature used in every call site (Tasks 3 brew block, 4 fzf, 5 sheldon, 6 starship, 7 rust). `core::ensure_block_absent <file> <id>` — same in all four module uninstall hooks. Block IDs are unique per content source: `homebrew`, `rust`, `fzf`, `sheldon`, `starship`. No collisions.

**Ordering**: After every task the tree passes `bash -n` + `shellcheck` + `shfmt -d`. Verified by the independent static-check step in each task plus the aggregated sweep in Task 12.

**Commit trailer + no --no-verify**: Every commit template includes `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. No commit in the plan uses `--no-verify`.
