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
| `lib/core.sh` | `core::` | `core::log`, `core::symlink`, `core::check_installed`, `core::require_version` |
| `lib/detect.sh` | `detect::` | `detect::os`, `detect::pkg_manager` |
| `install.sh` | `install::` | `install::run_module` |
| `uninstall.sh` | `uninstall::` | `uninstall::run_module` |
| `modules/*.sh` | `module::` / `_<mod>::` | `install`, `uninstall` (interface hooks); `_nvim::install_src` (module-local helper) |

One blank line between functions. Comment above each function describing what it does:

```bash
# Returns the absolute path to the dotfiles repository root.
core::repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}
```

Module-local `readonly` constants use an uppercase `_<MOD>_` prefix so they don't
collide across modules (the orchestrator cannot `unset` `readonly` vars between
iterations). Examples: `_NVIM_REPO`, `_TMUX_INSTALL_URL`, `_TMUX_CLONE_DIR`.

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

Exception: interactive prompts. `core::log` renders a boxed `[INFO]` prefix and a
trailing newline, which doesn't suit a multi-line question + `read -r` flow. For
those, use raw `printf '...' >&2` directly (see `modules/nvim.sh`'s pkg-vs-source
install menu, and `core::symlink`'s conflict prompt in `lib/core.sh`). The
"no raw printf in modules" rule covers informational log output, not prompts.

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

## Case Indentation

`case` branches sit at the same column as the `case` keyword itself. Bodies that
span multiple lines (or complex one-liners) are indented one level (2 spaces) under
the branch label. `.shfmt.toml` has `switch-case-indent = true`; the formatter
enforces this layout — write code that already matches it.

```bash
# Correct — case arms at the same column as `case`/`esac`
case "${DOTFILES_OS}" in
  mac) core::pkg_install sheldon starship ;;
  linux) core::pkg_install zsh sheldon starship ;;
esac

# Correct — multi-line body indented one level deeper
case "${level}" in
  INFO) prefix="[INFO]" ;;
  WARN)
    prefix="[WARN]"
    fd=2
    ;;
  *) prefix="[${level}]" ;;
esac

# Wrong — arms double-indented or flat
case "${DOTFILES_OS}" in
    mac) core::pkg_install sheldon starship ;;
    linux) core::pkg_install zsh sheldon starship ;;
esac
```

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
