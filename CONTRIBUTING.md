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
1. Run `superpowers:brainstorming` in Claude Code
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
