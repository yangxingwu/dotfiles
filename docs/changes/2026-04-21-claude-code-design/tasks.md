# Claude Code Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create all Claude Code configuration files to establish a governed, tool-enforced
development environment for the dotfiles project.

**Architecture:** Pure file creation — no runtime logic. Three layers: (1) tooling config
files that editors and formatters read automatically, (2) `.claude/rules/` that Claude reads
each session, (3) `.claude/settings.json` that governs permissions and triggers hooks.

**Tech Stack:** bash, shellcheck, shfmt, JSON, Markdown

---

### Task 1: Tooling Config Files

**Files:**
- Create: `.editorconfig`
- Create: `.shellcheckrc`
- Create: `.shfmt.toml`

- [ ] **Step 1: Create `.editorconfig`**

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.sh]
indent_style = space
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[*.toml]
indent_style = space
indent_size = 2

[*.json]
indent_style = space
indent_size = 2
```

- [ ] **Step 2: Create `.shellcheckrc`**

```
shell=bash
enable=require-variable-braces
disable=SC1091
```

SC1091 is disabled because shellcheck cannot resolve dynamic `source` paths such as
`source "${DOTFILES_DIR}/lib/core.sh"`.

- [ ] **Step 3: Create `.shfmt.toml`**

```toml
indent = 2
binary-next-line = true
switch-case-indent = true
space-redirects = true
```

- [ ] **Step 4: Commit**

```bash
git add .editorconfig .shellcheckrc .shfmt.toml
git commit -m "chore: add tooling config files (editorconfig, shellcheckrc, shfmt)"
```

---

### Task 2: CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Create `CLAUDE.md`**

```markdown
# dotfiles

A full auto-installer for macOS and Linux development configurations. Not just a config
archive — it installs packages, creates symlinks, and handles conflicts gracefully.

## Platform Support

- **macOS**: full install (all modules including GUI terminal configs)
- **Linux**: minimal/server install (core dev tools only, no GUI)

## Architecture

See `docs/changes/2026-04-21-dotfiles-project-design/design.md` for the full design.

Key invariants:
- **DRY_RUN**: all destructive operations check `DRY_RUN=1` before executing
- **Idempotent**: safe to run `install.sh` multiple times
- **No direct package manager calls in modules**: declare `DEPS_MAC`/`DEPS_LINUX`,
  let `lib/core.sh` dispatch

## Module Interface Contract

Every file in `modules/` must declare:

```bash
MODULE_NAME="<name>"
MODULE_DESC="<description>"
MODULE_PLATFORM="all"           # all | mac | linux

LINKS=(
  "config/<name>/file:${HOME}/.config/<name>/file"
)

DEPS_MAC=("<package>")
DEPS_LINUX=("<package>")

pre_install()  { :; }
post_install() { :; }
```

## Development Workflow

**Large changes** (new modules, architecture changes):
1. Run `superpowers:brainstorm` → produces `docs/changes/YYYY-MM-DD-<topic>/design.md`
2. Run `writing-plans` → produces `docs/changes/YYYY-MM-DD-<topic>/tasks.md`
3. Implement
4. Run `/change` to record a lightweight summary (optional if design.md covers it)

**Small changes** (bugfix, config tweak, small feature):
1. Implement directly
2. Session end: Stop hook will remind you if changes are undocumented
3. Run `/change` to record the change

All change docs save to `docs/changes/YYYY-MM-DD-<slug>/`.

## Shell Script Standards

See `.claude/rules/shell-style.md` (auto-loaded each session).

## Language

All code, comments, and documentation must be written in **English**.
```

- [ ] **Step 2: Verify file was written**

```bash
head -5 CLAUDE.md
```

Expected: first 5 lines of the file above.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md with project instructions for Claude Code"
```

---

### Task 3: Shell Style Rules

**Files:**
- Create: `.claude/rules/shell-style.md`

- [ ] **Step 1: Create `.claude/rules/` directory**

```bash
mkdir -p .claude/rules
```

- [ ] **Step 2: Create `.claude/rules/shell-style.md`**

```markdown
# Shell Script Style Guide

Auto-loaded by Claude Code every session. Follow all rules below when writing or modifying
shell scripts in this project.

Rules are derived from authoritative sources:
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Unofficial Bash Strict Mode](https://redsymbol.net/articles/unofficial-bash-strict-mode/)
- [BashFAQ](https://mywiki.wooledge.org/BashFAQ)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)

---

## Strict Mode

Every script must begin with:

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

Never omit any of these. From the Unofficial Bash Strict Mode:
- `set -e` — exit immediately if a command exits with non-zero status
- `set -u` — treat unset variables as errors
- `set -o pipefail` — the pipeline's return code is the last non-zero exit code
- `IFS=$'\n\t'` — prevents word splitting on spaces in filenames and expansions

---

## Variables

Always quote variable expansions. Always use braces.

```bash
# Correct
printf '%s\n' "${my_var}"
cp "${src_file}" "${dst_file}"

# Wrong — never do this
echo $my_var
cp $src_file $dst_file
```

Declare script-level constants with `readonly`:

```bash
readonly DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="1.0.0"
```

Declare function-scope variables with `local`:

```bash
my_function() {
  local result
  result="$(some_command)"
  printf '%s\n' "${result}"
}
```

---

## Function Naming

All functions use `namespace::name` format matching their source file:

| File | Namespace | Examples |
|---|---|---|
| `lib/core.sh` | `core::` | `core::log`, `core::symlink`, `core::backup` |
| `lib/detect.sh` | `detect::` | `detect::os`, `detect::pkg_manager` |
| `lib/preflight.sh` | `preflight::` | `preflight::scan_module`, `preflight::report_and_prompt` |
| `modules/*.sh` | `module::` | `pre_install`, `post_install` (these are interface hooks) |

One blank line between functions. Comment above each function describing what it does:

```bash
# Returns the absolute path to the dotfiles repository root.
core::repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}
```

---

## Conditionals

Use `[[ ]]` not `[ ]`. The double-bracket form is safer and supports regex:

```bash
# Correct
if [[ -f "${file}" ]]; then ...
if [[ "${var}" == "value" ]]; then ...
if [[ "${str}" =~ ^[0-9]+$ ]]; then ...

# Wrong
if [ -f "$file" ]; then ...
if test -f "$file"; then ...
```

---

## Output

Use `printf` not `echo`. The `echo` built-in behaviour varies across systems and shells.

```bash
# Correct
printf 'Installing %s...\n' "${package}"
printf 'error: file not found: %s\n' "${path}" >&2

# Wrong
echo "Installing ${package}..."
```

All user-visible output in modules must go through `core::log`. Never use raw `printf`
or `echo` in `modules/*.sh`:

```bash
# In a module — correct
core::log INFO "Configuring ${MODULE_NAME}"

# In a module — wrong
printf 'Configuring %s\n' "${MODULE_NAME}"
```

Only `lib/core.sh` itself uses direct `printf`.

---

## Error Handling

Send error messages to stderr. In `lib/` files:

```bash
printf 'error: %s\n' "${message}" >&2
return 1
```

In module files, use `core::log`:

```bash
if [[ ! -d "${config_dir}" ]]; then
  core::log ERROR "Config directory not found: ${config_dir}"
  return 1
fi
```

---

## Binary Detection

Use `command -v` not `which`. The `which` command is not portable:

```bash
# Correct
if command -v brew &>/dev/null; then ...

# Wrong
if which brew &>/dev/null; then ...
if type brew &>/dev/null; then ...
```

---

## Directory Changes

Never use bare `cd`. Always guard with a subshell or `pushd`/`popd`:

```bash
# Correct — subshell (preferred for short operations)
result="$(cd "${dir}" && some_command)"

# Correct — pushd/popd (preferred when multiple commands run in the dir)
pushd "${dir}" > /dev/null
do_something
do_another_thing
popd > /dev/null

# Wrong — bare cd leaves the script in a different directory on failure
cd "${dir}"
do_something
```

---

## DRY_RUN Pattern

All destructive operations must check `DRY_RUN` before executing:

```bash
core::symlink() {
  local src="$1"
  local target="$2"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log INFO "[DRY-RUN] Would symlink ${src} → ${target}"
    return 0
  fi

  ln -sf "${src}" "${target}"
  core::log INFO "Symlinked ${src} → ${target}"
}
```

The `DRY_RUN` variable is set by `install.sh` and exported to all sourced scripts.

---

## Comments

Describe *what* and *why*, not *how*. The code itself shows how.

```bash
# Wrong — describes the how, not the why
# iterate over each file in the array and create a symlink
for link in "${LINKS[@]}"; do

# Correct — describes why this check exists
# Skip files already correctly symlinked — install.sh is designed to be idempotent
for link in "${LINKS[@]}"; do
```

---

## Formatting

shfmt is applied automatically on every save (via PostToolUse hook). Write code at the
correct indentation level — shfmt handles the rest. Key shfmt settings (from `.shfmt.toml`):

- indent: 2 spaces
- binary operators (`&&`, `||`) go at start of next line, not end of current
- `case` items are indented
- space before redirections (`> file`, not `>file`)
```

- [ ] **Step 3: Commit**

```bash
git add .claude/rules/shell-style.md
git commit -m "docs: add shell style rules for Claude Code (.claude/rules/shell-style.md)"
```

---

### Task 4: Hook Scripts

**Files:**
- Create: `.claude/hooks/post-edit.sh`
- Create: `.claude/hooks/pre-stop.sh`

- [ ] **Step 1: Create `.claude/hooks/` directory**

```bash
mkdir -p .claude/hooks
```

- [ ] **Step 2: Create `.claude/hooks/post-edit.sh`**

```bash
#!/usr/bin/env bash
# .claude/hooks/post-edit.sh
# Triggered after Edit/Write tool calls on .sh files.
# Runs syntax check, shellcheck lint, and shfmt auto-format.
set -euo pipefail
IFS=$'\n\t'

readonly file_path="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"

# Only process shell scripts that exist on disk
[[ -z "${file_path}" ]] && exit 0
[[ "${file_path}" != *.sh ]] && exit 0
[[ ! -f "${file_path}" ]] && exit 0

printf 'post-edit: %s\n' "${file_path}"

bash -n "${file_path}" \
  || { printf 'error: syntax check failed: %s\n' "${file_path}" >&2; exit 1; }

shellcheck "${file_path}" \
  || { printf 'error: shellcheck failed: %s\n' "${file_path}" >&2; exit 1; }

# shfmt reads .shfmt.toml from the project root automatically
shfmt -w "${file_path}" \
  || { printf 'error: shfmt failed: %s\n' "${file_path}" >&2; exit 1; }

printf 'post-edit: OK\n'
```

- [ ] **Step 3: Create `.claude/hooks/pre-stop.sh`**

```bash
#!/usr/bin/env bash
# .claude/hooks/pre-stop.sh
# Triggered at session end. Shows git diff summary and reminds about undocumented changes.
set -euo pipefail
IFS=$'\n\t'

# Navigate to repo root — hook may run from any working directory
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "${repo_root}"

diff_stat="$(git diff --stat HEAD 2>/dev/null)"
[[ -z "${diff_stat}" ]] && exit 0

printf '\n── Session Summary ──────────────────────────────────────────────\n'
printf '%s\n' "${diff_stat}"
printf '\nUndocumented changes detected. Run /change if this deserves a record.\n'
printf '─────────────────────────────────────────────────────────────────\n\n'
```

- [ ] **Step 4: Verify both hook scripts**

```bash
bash -n .claude/hooks/post-edit.sh && echo "post-edit.sh: syntax OK"
bash -n .claude/hooks/pre-stop.sh && echo "pre-stop.sh: syntax OK"
shellcheck .claude/hooks/post-edit.sh && echo "post-edit.sh: shellcheck OK"
shellcheck .claude/hooks/pre-stop.sh && echo "pre-stop.sh: shellcheck OK"
```

Expected:
```
post-edit.sh: syntax OK
pre-stop.sh: syntax OK
post-edit.sh: shellcheck OK
pre-stop.sh: shellcheck OK
```

- [ ] **Step 5: Make hooks executable**

```bash
chmod +x .claude/hooks/post-edit.sh .claude/hooks/pre-stop.sh
```

- [ ] **Step 6: Commit**

```bash
git add .claude/hooks/
git commit -m "feat: add Claude Code hook scripts (post-edit lint/format, pre-stop summary)"
```

---

### Task 5: settings.json

**Files:**
- Create: `.claude/settings.json`

- [ ] **Step 1: Create `.claude/settings.json`**

```json
{
  "permissions": {
    "allow": [
      "Bash(bash -n *)",
      "Bash(shellcheck *)",
      "Bash(shfmt *)",
      "Bash(git status)",
      "Bash(git log *)",
      "Bash(git diff *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(./install.sh --dry-run*)",
      "Bash(./install.sh --module * --dry-run)"
    ],
    "deny": [
      "Bash(./install.sh)",
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Read(~/.ssh/**)",
      "Read(~/.gnupg/**)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/post-edit.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/pre-stop.sh"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Verify JSON is valid**

```bash
python3 -c "import json; json.load(open('.claude/settings.json')); print('Valid JSON')"
```

Expected: `Valid JSON`

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "feat: add Claude Code settings.json with permissions and hooks"
```

---

### Task 6: Slash Commands

**Files:**
- Create: `.claude/commands/lint.md`
- Create: `.claude/commands/format.md`
- Create: `.claude/commands/dry-run.md`
- Create: `.claude/commands/new-module.md`
- Create: `.claude/commands/change.md`

- [ ] **Step 1: Create `.claude/commands/` directory**

```bash
mkdir -p .claude/commands
```

- [ ] **Step 2: Create `.claude/commands/lint.md`**

```markdown
Run shellcheck on all shell scripts in this project and report results.

```bash
shellcheck lib/*.sh modules/*.sh install.sh uninstall.sh .claude/hooks/*.sh
```

If shellcheck reports issues, list each one and describe what needs fixing. If all pass,
confirm with "All shell scripts pass shellcheck."
```

- [ ] **Step 3: Create `.claude/commands/format.md`**

```markdown
Run shfmt on all shell scripts in this project to auto-format them in place.

```bash
shfmt -w lib/*.sh modules/*.sh install.sh uninstall.sh .claude/hooks/*.sh
```

After formatting, run `git diff --stat` to show which files changed. Report a summary
of what was reformatted.
```

- [ ] **Step 4: Create `.claude/commands/dry-run.md`**

```markdown
Run the dotfiles installer in dry-run mode. No changes are made to the system.

```bash
./install.sh --dry-run
```

Summarise the output:
- Which modules would be installed
- Which symlinks would be created (source → target)
- Which packages would be installed
- Any conflicts detected and how they would be resolved
```

- [ ] **Step 5: Create `.claude/commands/new-module.md`**

```markdown
Scaffold a new dotfiles module named: $ARGUMENTS

Create these three files:

**1. `modules/$ARGUMENTS.sh`**

```bash
#!/usr/bin/env bash
# modules/$ARGUMENTS.sh — [brief description of what this module manages]
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="$ARGUMENTS"
MODULE_DESC="[One-line description]"
MODULE_PLATFORM="all"           # all | mac | linux

LINKS=(
  # Format: "config/$ARGUMENTS/file:${HOME}/.config/$ARGUMENTS/file"
)

DEPS_MAC=()
DEPS_LINUX=()

pre_install() { :; }
post_install() { :; }
```

**2. `docs/modules/$ARGUMENTS.md`**

```markdown
# Module: $ARGUMENTS

[Description of what this module manages]

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/$ARGUMENTS/` | `~/.config/$ARGUMENTS/` | all |

## Dependencies

| Platform | Packages |
|---|---|
| macOS | — |
| Linux | — |

## Notes

[Any special setup steps, post-install configuration, or caveats]
```

**3. `.claude/rules/module-$ARGUMENTS.md`**

```markdown
---
paths:
  - "modules/$ARGUMENTS.sh"
  - "config/$ARGUMENTS/**"
---

@docs/modules/$ARGUMENTS.md
```

After creating all three files, remind the user to:
1. Fill in `MODULE_DESC`, `MODULE_PLATFORM`, `LINKS`, `DEPS_MAC`, `DEPS_LINUX`
2. Create `config/$ARGUMENTS/` and add the actual config files
3. Update `docs/modules/$ARGUMENTS.md` with accurate symlink and dependency tables
4. Run `./install.sh --module $ARGUMENTS --dry-run` to verify the module works
```

- [ ] **Step 6: Create `.claude/commands/change.md`**

```markdown
Generate a change document for the current session's work.

1. Run these commands to understand what changed:

```bash
git diff HEAD
git log --oneline -5
```

2. Based on the diff, determine:
   - A short slug for this change (e.g., `fix-tmux-symlink`, `add-ghostty-module`)
   - The change type: `bugfix` | `feature` | `refactor` | `chore`
   - Which files were affected (list the key ones)

3. Create the directory and file: `docs/changes/YYYY-MM-DD-<slug>/change.md`
   (Use today's actual date in YYYY-MM-DD format)

4. Write the file with this content:

```markdown
# <type>: <one-line summary>

Date: YYYY-MM-DD
Type: bugfix | feature | refactor | chore
Files: <comma-separated list of key changed files>

## Background

[What problem or context triggered this change. One to three sentences.]

## What changed

- [Specific change 1]
- [Specific change 2]

## Why

[Reasoning or trade-off, if non-obvious. Omit if self-evident.]
```

5. Report the path of the created document and its content.
```

- [ ] **Step 7: Commit**

```bash
git add .claude/commands/
git commit -m "feat: add slash commands (lint, format, dry-run, new-module, change)"
```

---

### Task 7: Project Documentation

**Files:**
- Create: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `LICENSE`

- [ ] **Step 1: Create `README.md`**

```markdown
# dotfiles

Full auto-installer for macOS and Linux development configurations.

## Overview

Installs packages, creates symlinks, and handles conflicts gracefully — not just a config
archive. Re-running is safe: the installer is fully idempotent.

## Platform Support

| Platform | Support |
|---|---|
| macOS | Full (all modules including GUI terminal configs) |
| Linux | Minimal (core dev tools, SSH-friendly, no GUI terminals) |

## Prerequisites

- bash 4+
- git

## Quick Install

```bash
git clone https://github.com/<your-username>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh --dry-run    # preview changes without touching anything
./install.sh              # apply
```

## Modules

| Module | Platform | What it manages |
|---|---|---|
| `git` | all | gitconfig + custom hooks |
| `zsh` | all | sheldon (plugin manager) + starship (prompt) |
| `nvim` | all | Neovim configuration (LazyVim) |
| `tmux` | all | tmux configuration |
| `ghostty` | macOS | Ghostty terminal config |
| `kitty` | macOS | Kitty terminal config |
| `iterm2` | macOS | iTerm2 preferences |

See [`docs/modules/`](docs/modules/) for per-module details.

## Usage

```bash
# Install all modules for the current platform
./install.sh

# Preview without making changes
./install.sh --dry-run

# Install a single module
./install.sh --module nvim

# Preview a single module
./install.sh --module nvim --dry-run
```

## Conflict Handling

Before making any changes, the installer scans all symlink targets for conflicts.
If conflicts are found, you choose one resolution strategy for the entire run:

- **Backup all** — existing files move to `~/.dotfiles-backup/YYYYMMDD-HHMMSS/`
- **Skip all** — conflicting targets are left untouched (those modules are skipped)
- **Interactive** — decide each conflict individually

## Restoring a Backup

```bash
# List available backups
ls ~/.dotfiles-backup/

# Restore a specific file
cp -r ~/.dotfiles-backup/20260421-143022/.config/nvim ~/.config/nvim
```

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).
```

- [ ] **Step 2: Create `CONTRIBUTING.md`**

```markdown
# Contributing

## Development Environment

Install required tools:

```bash
# macOS
brew install shellcheck shfmt

# Linux (apt)
apt-get install shellcheck
# shfmt: download from https://github.com/mvdan/sh/releases
```

Install [Claude Code](https://claude.ai/code) for AI-assisted development (recommended).

## Development Workflow

See `CLAUDE.md` for the full workflow. Summary:

**Large changes** (new module, architecture change, refactor):
1. Run `superpowers:brainstorm` in Claude Code
2. Design doc + tasks saved to `docs/changes/YYYY-MM-DD-<topic>/`
3. Implement following the tasks file
4. Optionally run `/change` for a lightweight summary

**Small changes** (bugfix, config tweak):
1. Implement directly
2. Run `/change` to record the change in `docs/changes/YYYY-MM-DD-<slug>/change.md`

## Adding a New Module

Use the `/new-module <name>` slash command in Claude Code. It creates:

- `modules/<name>.sh` — module with standard interface (fill in LINKS, DEPS)
- `docs/modules/<name>.md` — documentation template
- `.claude/rules/module-<name>.md` — path-scoped context rule

Then add the actual config files to `config/<name>/` and run:

```bash
./install.sh --module <name> --dry-run
```

## Code Style

Shell scripts follow `.claude/rules/shell-style.md`. Key rules:

- `set -euo pipefail` + `IFS=$'\n\t'` in every script
- Namespace all functions: `core::`, `detect::`, `preflight::`, `module::`
- Use `[[ ]]` not `[ ]`; `printf` not `echo`
- All user-visible output in modules goes through `core::log`

The following are enforced automatically on every save:
- `bash -n` — syntax check
- `shellcheck` — lint
- `shfmt` — auto-format (reads `.shfmt.toml`)

## Commit Conventions

[Conventional Commits](https://www.conventionalcommits.org/) format:

```
feat: add ghostty module
fix: correct nvim symlink target path
chore: update sheldon plugins.toml
docs: add tmux module documentation
refactor: extract backup timestamp to core.sh
```

## Change Documentation

Every meaningful change should have a record in `docs/changes/`. Run `/change` at session
end to generate `docs/changes/YYYY-MM-DD-<slug>/change.md` from the current git diff.

Large changes already have `design.md` + `tasks.md` in their directory — a `change.md`
is optional but appreciated for a concise summary.
```

- [ ] **Step 3: Create `LICENSE`**

Replace `[Your Name]` with your actual name before committing.

```
MIT License

Copyright (c) 2026 [Your Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 4: Update `[Your Name]` in LICENSE**

Open `LICENSE` and replace `[Your Name]` with the actual copyright holder name.

- [ ] **Step 5: Commit**

```bash
git add README.md CONTRIBUTING.md LICENSE
git commit -m "docs: add README, CONTRIBUTING guide, and MIT LICENSE"
```
