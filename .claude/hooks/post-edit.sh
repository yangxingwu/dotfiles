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
