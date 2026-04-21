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
