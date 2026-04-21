# Claude Code Configuration Design

Date: 2026-04-21
Type: design
Status: approved

## Overview

Configuration of the Claude Code development environment for this dotfiles project. Covers
tooling config, Claude's behavioural rules, automation hooks, slash commands, workflow
conventions, and documentation standards.

---

## File Structure

```
dotfiles/
├── CLAUDE.md                        # project overview + architecture decisions
├── .editorconfig                    # universal editor formatting config
├── .shellcheckrc                    # shellcheck lint rules
├── .shfmt.toml                      # shfmt formatting config
└── .claude/
    ├── settings.json                # permissions + hooks
    ├── rules/
    │   └── shell-style.md           # Claude's shell script behavioural rules
    ├── commands/
    │   ├── lint.md                  # /lint — run shellcheck on all .sh files
    │   ├── format.md                # /format — run shfmt on all .sh files
    │   ├── dry-run.md               # /dry-run — ./install.sh --dry-run
    │   ├── new-module.md            # /new-module <name> — scaffold a new module
    │   └── change.md                # /change — generate change doc from git diff
    └── hooks/
        ├── post-edit.sh             # bash -n + shellcheck + shfmt on changed .sh files
        └── pre-stop.sh              # git diff --stat + undocumented change reminder
```

---

## CLAUDE.md

Top-level project instructions for Claude. Contains:

- Project purpose and architecture summary
- Module interface contract (what every module must declare)
- Key invariants (DRY_RUN, idempotency, no direct brew/apt calls in modules)
- Documentation workflow (see Workflow section below)
- Pointer to `.claude/rules/shell-style.md` for shell coding standards
- Language rule: all code, comments, and documentation must be written in English

Does NOT contain: style rules (those live in `shell-style.md`), formatting rules (those live
in tooling config files).

---

## Tooling Config Files

### `.editorconfig`

Universal formatting enforced by editors and editorconfig-aware tools:

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

### `.shellcheckrc`

```bash
shell=bash
enable=require-variable-braces
disable=SC1091
```

`SC1091` is disabled because shellcheck cannot follow dynamic `source` paths (e.g., sourcing
lib files relative to `BASH_SOURCE`).

### `.shfmt.toml`

```toml
indent = 2
binary-next-line = true
switch-case-indent = true
space-redirects = true
```

---

## Shell Script Rules: `.claude/rules/shell-style.md`

This file is auto-loaded by Claude Code as a persistent behavioural instruction. It covers
rules that automated tools cannot enforce — things requiring judgement or project-specific
conventions.

**What belongs here:**
- Rules not covered by shellcheck/shfmt (comment style, error message format, function
  organisation, module structure conventions)
- Formatting rules that Claude should follow when writing initial code (even though shfmt
  will auto-fix after the fact, writing correctly from the start reduces noise)
- Project-specific conventions (namespacing, logging, DRY_RUN pattern)

**What does NOT belong here:**
- Rules already enforced by shellcheck (redundant, and risks conflicts if they differ)
- Rules already enforced by shfmt (same reason)

### Authoritative References

Rules in `shell-style.md` are derived directly from these sources (prefer quoting original
text over paraphrasing):

| Reference | URL |
|---|---|
| Google Shell Style Guide | https://google.github.io/styleguide/shellguide.html |
| Unofficial Bash Strict Mode (Aaron Maxwell) | https://redsymbol.net/articles/unofficial-bash-strict-mode/ |
| BashFAQ (Wooledge community) | https://mywiki.wooledge.org/BashFAQ |
| ShellCheck Wiki | https://www.shellcheck.net/wiki/ |
| GNU Bash Manual | https://www.gnu.org/software/bash/manual/bash.html |

### Core Rules Summary

1. **Strict mode**: every script must begin with `set -euo pipefail` + `IFS=$'\n\t'`
2. **Variable quoting**: always `"${var}"`, never bare `$var`
3. **Constants**: `readonly` for script-level constants
4. **Function variables**: `local` for all function-scope variables
5. **Namespacing**: all functions use `namespace::name` — `core::`, `detect::`,
   `preflight::`, `module::`
6. **Conditionals**: `[[ ]]` not `[ ]`
7. **Output**: `printf` not `echo` for user-facing output
8. **Errors**: always to stderr — `printf 'error: %s\n' "msg" >&2`
9. **Binary detection**: `command -v` not `which`
10. **Directory changes**: never bare `cd`; use subshell `(cd dir && ...)` or
    `pushd`/`popd`
11. **Logging**: all user-visible output goes through `lib/core.sh` log functions;
    never raw `printf`/`echo` in modules
12. **Comments**: describe *what* and *why*, not *how*; one blank line between functions

---

## `settings.json`

### Permissions

Pre-approved (no confirmation prompt):
```json
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
]
```

Hard-blocked (safety guardrails — prevents Claude from modifying real system configs
without explicit dry-run verification):
```json
"deny": [
  "Bash(./install.sh)",
  "Bash(rm -rf *)",
  "Bash(sudo *)",
  "Read(~/.ssh/**)",
  "Read(~/.gnupg/**)"
]
```

`./install.sh` without `--dry-run` is blocked by default. Claude must always use
`--dry-run` to verify behaviour before the user manually runs the real install.

### Hooks

**PostToolUse** — triggered after every `Edit` or `Write` tool call on a `.sh` file:
runs `bash -n` (syntax check) + `shellcheck` + `shfmt -w` (auto-format in place).

**Stop** — triggered at session end: shows `git diff --stat HEAD` and reminds the user
if there are undocumented changes.

Hook commands are extracted to `.claude/hooks/` scripts (not inlined in JSON) so they
can be linted, tested, and read easily.

```json
{
  "permissions": {
    "allow": [...],
    "deny": [...]
  },
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{ "type": "command", "command": ".claude/hooks/post-edit.sh" }]
    }],
    "Stop": [{
      "hooks": [{ "type": "command", "command": ".claude/hooks/pre-stop.sh" }]
    }]
  }
}
```

---

## Slash Commands: `.claude/commands/`

| Command | File | Behaviour |
|---|---|---|
| `/lint` | `lint.md` | Run shellcheck on all `.sh` files in `lib/`, `modules/`, `install.sh`, `uninstall.sh` |
| `/format` | `format.md` | Run shfmt on all `.sh` files (in-place) |
| `/dry-run` | `dry-run.md` | Run `./install.sh --dry-run` and summarise output |
| `/new-module` | `new-module.md` | Scaffold a new module file with full interface contract |
| `/change` | `change.md` | Read `git diff HEAD`, generate and save a change doc to `docs/changes/YYYY-MM-DD-<slug>/change.md` |

---

## Workflow Design

### Two Tracks

**Large changes** (new architecture, new modules, refactoring):
```
superpowers:brainstorm
  → docs/changes/YYYY-MM-DD-<topic>/design.md
  → writing-plans
  → docs/changes/YYYY-MM-DD-<topic>/tasks.md
  → implementation
  → /change (optional lightweight summary, or link to design.md)
```

**Small changes** (bugfix, config tweak, small feature):
```
direct implementation
  → session end: Stop hook shows diff + reminder
  → /change → docs/changes/YYYY-MM-DD-<slug>/change.md
```

### Documentation Structure

All change documentation lives under `docs/changes/`:

```
docs/changes/
├── 2026-04-21-dotfiles-project-design/    # brainstorm output (large change)
│   ├── design.md
│   └── tasks.md
├── 2026-04-21-claude-code-design/         # brainstorm output (large change)
│   ├── design.md
│   └── tasks.md
└── 2026-04-22-fix-tmux-symlink/           # small change
    └── change.md
```

Rules:
- Every change gets a `YYYY-MM-DD-<slug>/` directory
- Large changes (brainstorm-driven): `design.md` + `tasks.md` (+ any attachments)
- Small changes: single `change.md`
- brainstorm default save path is overridden via `CLAUDE.md` to use `docs/changes/`

### `change.md` Template (small changes)

```markdown
# <type>: <one-line summary>

Date: YYYY-MM-DD
Type: bugfix | feature | refactor | chore
Files: <affected files>

## Background
What problem or context triggered this change.

## What changed
- Bullet points of specific changes.

## Why
Reasoning or trade-off, if non-obvious.
```

### Stop Hook Reminder

At session end, `.claude/hooks/pre-stop.sh` outputs:

```
── Session Summary ─────────────────────────────
<git diff --stat HEAD output>

Undocumented changes detected. Run /change if this deserves a record.
────────────────────────────────────────────────
```

The reminder is shown only when there are uncommitted or undocumented changes. It is
advisory — the user decides whether to run `/change`.
