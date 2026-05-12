# Output Verbosity Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-level verbosity framework (normal/verbose) so `install.sh` shows clean progress by default and hides noisy package manager/compiler output behind a log file.

**Architecture:** A new `core::run_cmd` function wraps noisy external commands, capturing their stdout/stderr to a log file. In normal mode only structured `core::log` messages are visible; in verbose mode command output is tee'd to both terminal and log. On failure, the last 20 lines are displayed with the log path.

**Tech Stack:** Bash (4.3+), existing `lib/core.sh` infrastructure

---

### Task 1: Add `DOTFILES_VERBOSITY` global and `--verbose` flag parsing

**Files:**
- Modify: `lib/core.sh:155-214` (add `--verbose` to `core::parse_args`)
- Modify: `install.sh:40-41` (initialize `DOTFILES_VERBOSITY` and `DOTFILES_LOG_FILE`)

- [ ] **Step 1: Add verbosity initialization to `install.sh`**

In `install.sh`, after the `readonly DOTFILES_ROOT` line (line 29) and before the `source` lines, add log file initialization:

```bash
# Verbosity: "normal" (default) suppresses command output; "verbose" passes it through.
DOTFILES_VERBOSITY="normal"
DOTFILES_LOG_FILE="/tmp/dotfiles-install-$(date +%Y%m%d-%H%M%S).log"
```

These must NOT be `readonly` — `core::parse_args` may change `DOTFILES_VERBOSITY`.

- [ ] **Step 2: Add `--verbose` / `-v` to `core::parse_args`**

In `lib/core.sh`, inside the `core::parse_args()` function's `while` loop `case` statement (around line 176), add a new branch before the `*)` catch-all:

```bash
    --verbose | -v)
      DOTFILES_VERBOSITY="verbose"
      shift
      ;;
```

Also update `core::usage()` to document the new flag. Add this line after the `--help` line:

```bash
  printf '  -v, --verbose      Show full command output (default: summary only)\n'
```

- [ ] **Step 3: Verify flag parsing works**

Run:
```bash
cd /Volumes/Code/dotfiles && bash -c 'source lib/modules.sh; source lib/detect.sh; source lib/core.sh; DOTFILES_VERBOSITY=normal; core::parse_args --verbose; printf "%s\n" "${DOTFILES_VERBOSITY}"'
```

Expected output: `verbose`

Run:
```bash
cd /Volumes/Code/dotfiles && bash -c 'source lib/modules.sh; source lib/detect.sh; source lib/core.sh; DOTFILES_VERBOSITY=normal; core::parse_args; printf "%s\n" "${DOTFILES_VERBOSITY}"'
```

Expected output: `normal`

- [ ] **Step 4: Commit**

```bash
git add install.sh lib/core.sh
git commit -m "feat: add --verbose flag and DOTFILES_VERBOSITY global

Introduces the verbosity framework. Default is 'normal' (summary only);
--verbose/-v enables full command output passthrough."
```

---

### Task 2: Implement `core::run_cmd`

**Files:**
- Modify: `lib/core.sh` (add new function after `core::pkg_install`, around line 92)

- [ ] **Step 1: Add `core::run_cmd` function to `lib/core.sh`**

Insert after the closing `}` of `core::pkg_install` (after line 92), before the `# Managed blocks` comment (line 94):

```bash
# core::run_cmd <description> <command> [args...]
# Execute a command with output control based on DOTFILES_VERBOSITY.
# In normal mode: output goes to log file only; on failure, tail 20 lines.
# In verbose mode: output streams to terminal AND log file.
# Always appends to DOTFILES_LOG_FILE. Returns the command's exit code.
core::run_cmd() {
  local description="${1}"
  shift

  local start_time end_time elapsed exit_code=0

  core::log INFO "${description}..."
  printf '\n=== %s ===\n' "${description}" >>"${DOTFILES_LOG_FILE}"

  start_time="$(date +%s)"

  if [[ "${DOTFILES_VERBOSITY}" == "verbose" ]]; then
    "$@" 2>&1 | tee -a "${DOTFILES_LOG_FILE}" || exit_code="${PIPESTATUS[0]}"
  else
    "$@" >>"${DOTFILES_LOG_FILE}" 2>&1 || exit_code=$?
  fi

  end_time="$(date +%s)"
  elapsed="$((end_time - start_time))"

  if [[ "${exit_code}" -eq 0 ]]; then
    core::log INFO "Done: ${description} (${elapsed}s)"
  else
    core::log ERROR "Failed: ${description} (exit ${exit_code}, ${elapsed}s)"
    printf '── last 20 lines ──────────────────────────────────\n' >&2
    tail -20 "${DOTFILES_LOG_FILE}" >&2
    printf '───────────────────────────────────────────────────\n' >&2
    printf 'Full log: %s\n' "${DOTFILES_LOG_FILE}" >&2
    return "${exit_code}"
  fi
}
```

- [ ] **Step 2: Test `core::run_cmd` in normal mode (success case)**

```bash
cd /Volumes/Code/dotfiles && DOTFILES_VERBOSITY=normal DOTFILES_LOG_FILE=/tmp/test-run-cmd.log bash -c '
source lib/modules.sh; source lib/detect.sh; source lib/core.sh
core::run_cmd "Listing files" ls /tmp
'
```

Expected: See `[INFO] Listing files...` and `[INFO] Done: Listing files (0s)` on terminal. No ls output on terminal. Check log: `cat /tmp/test-run-cmd.log` should contain the ls output.

- [ ] **Step 3: Test `core::run_cmd` in verbose mode (success case)**

```bash
cd /Volumes/Code/dotfiles && DOTFILES_VERBOSITY=verbose DOTFILES_LOG_FILE=/tmp/test-run-cmd-v.log bash -c '
source lib/modules.sh; source lib/detect.sh; source lib/core.sh
core::run_cmd "Listing files" ls /tmp
'
```

Expected: See `[INFO] Listing files...`, then the ls output on terminal, then `[INFO] Done: Listing files (0s)`.

- [ ] **Step 4: Test `core::run_cmd` failure case**

```bash
cd /Volumes/Code/dotfiles && DOTFILES_VERBOSITY=normal DOTFILES_LOG_FILE=/tmp/test-run-cmd-fail.log bash -c '
set +e
source lib/modules.sh; source lib/detect.sh; source lib/core.sh
core::run_cmd "Failing command" ls /nonexistent_path_xyz
printf "exit: %s\n" "$?"
'
```

Expected: See `[ERROR] Failed: Failing command (exit ...`, followed by the last-20-lines block showing the ls error, and the log path.

- [ ] **Step 5: Commit**

```bash
git add lib/core.sh
git commit -m "feat: implement core::run_cmd for output-controlled execution

Wraps external commands with log capture and verbosity-aware display.
Normal mode silences output (log only); verbose mode tees to terminal.
On failure, shows last 20 lines of output for quick diagnosis."
```

---

### Task 3: Add `core::log` log-file mirroring

**Files:**
- Modify: `lib/core.sh:8-31` (the `core::log` function)

- [ ] **Step 1: Add log-file append to `core::log`**

At the end of `core::log`, just before the closing `}`, add a conditional append to the log file. The full function becomes:

```bash
core::log() {
  local level="${1}" message="${2}" fd=1

  case "${level}" in
  INFO) fd=1 ;;
  WARN | ERROR) fd=2 ;;
  esac

  # -t N tests whether fd N is a terminal. Check the fd we actually write to,
  # so colours are emitted only when that specific fd goes to a TTY.
  local color="" reset=""
  if [[ -t "${fd}" ]]; then
    reset=$'\033[0m'
    case "${level}" in
    INFO) color=$'\033[0;32m' ;;
    WARN) color=$'\033[0;33m' ;;
    ERROR) color=$'\033[0;31m' ;;
    esac
  fi

  printf '%s %s\n' "${color}[${level}]${reset}" "${message}" >&"${fd}"

  # Mirror to log file when active (no colour codes in log).
  if [[ -n "${DOTFILES_LOG_FILE:-}" ]] && [[ -n "${DOTFILES_LOG_FILE}" ]]; then
    printf '[%s] %s\n' "${level}" "${message}" >>"${DOTFILES_LOG_FILE}"
  fi
}
```

- [ ] **Step 2: Verify log mirroring**

```bash
cd /Volumes/Code/dotfiles && DOTFILES_LOG_FILE=/tmp/test-log-mirror.log bash -c '
source lib/modules.sh; source lib/detect.sh; source lib/core.sh
core::log INFO "Test message"
core::log ERROR "Error message"
cat /tmp/test-log-mirror.log
'
```

Expected: Terminal shows coloured `[INFO] Test message` and `[ERROR] Error message`. Log file contains plain `[INFO] Test message` and `[ERROR] Error message` (no ANSI codes).

- [ ] **Step 3: Verify no log file case still works**

```bash
cd /Volumes/Code/dotfiles && unset DOTFILES_LOG_FILE && bash -c '
source lib/modules.sh; source lib/detect.sh; source lib/core.sh
core::log INFO "No log file set"
'
```

Expected: Normal output to terminal, no errors about missing log file.

- [ ] **Step 4: Commit**

```bash
git add lib/core.sh
git commit -m "feat: mirror core::log output to DOTFILES_LOG_FILE

When DOTFILES_LOG_FILE is set, all core::log messages are appended
to it (without ANSI colour codes). Gracefully no-ops when unset."
```

---

### Task 4: Add final install summary with timing and log path

**Files:**
- Modify: `lib/core.sh:219-254` (the `core::run_module` function)
- Modify: `install.sh:65-76` (the main loop and summary)

- [ ] **Step 1: Add module-level timing to `core::run_module`**

Replace the current `core::run_module` function body (lines 219-254 of `lib/core.sh`) with timing and failure tracking. The full function:

```bash
# core::run_module <action> <name> <index> <total>
# Sources modules/<name>.sh, validates the module interface, skips if the
# platform doesn't match, then calls the given action (install or uninstall).
# Tracks timing and failure state for the final summary.
core::run_module() {
  local action="${1}" name="${2}" index="${3}" total="${4}"
  local module_file="${DOTFILES_ROOT}/modules/${name}.sh"

  # Reset hooks to no-op defaults before sourcing the module file.
  # The module's install()/uninstall() definitions will overwrite these.
  # shellcheck disable=SC2317
  install() { :; }
  # shellcheck disable=SC2317
  uninstall() { :; }
  unset MODULE_NAME MODULE_DESC MODULE_PLATFORM

  # shellcheck source=/dev/null
  source "${module_file}"

  : "${MODULE_NAME:?missing MODULE_NAME in ${module_file}}"
  : "${MODULE_DESC:?missing MODULE_DESC in ${module_file}}"
  : "${MODULE_PLATFORM:?missing MODULE_PLATFORM in ${module_file}}"

  if [[ "${MODULE_NAME}" != "${name}" ]]; then
    core::log ERROR "MODULE_NAME=${MODULE_NAME} does not match filename ${name}.sh"
    return 1
  fi
  if [[ "${MODULE_PLATFORM}" != "all" ]] &&
    [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    core::log INFO "Skipping ${name} (platform: ${MODULE_PLATFORM})"
    core::summary "  ${name}"
    core::summary "    — skipped (${MODULE_PLATFORM} only)"
    return 0
  fi

  local start_time end_time elapsed
  start_time="$(date +%s)"

  core::log INFO "▶ [${index}/${total}] ${name} — ${MODULE_DESC}"
  core::summary "  ${name}"

  if "${action}"; then
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    core::log INFO "✓ ${name} (${elapsed}s)"
    _CORE_MODULES_OK=$((_CORE_MODULES_OK + 1))
  else
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    core::log ERROR "✗ ${name} failed (${elapsed}s)"
    _CORE_MODULES_FAILED+=("${name}")
  fi
}
```

- [ ] **Step 2: Add module tracking variables to `lib/core.sh`**

After the `_CORE_SUMMARY=()` line (around line 257), add:

```bash
# Module outcome tracking for final summary.
_CORE_MODULES_OK=0
_CORE_MODULES_FAILED=()
_CORE_INSTALL_START=""
```

- [ ] **Step 3: Add `core::print_final_summary` function to `lib/core.sh`**

Add after `core::print_summary` (after line 296):

```bash
# core::print_final_summary
# Prints the final install/uninstall result with timing and log path.
core::print_final_summary() {
  local end_time elapsed
  end_time="$(date +%s)"
  elapsed="$((end_time - _CORE_INSTALL_START))"

  local total_modules=$((_CORE_MODULES_OK + ${#_CORE_MODULES_FAILED[@]}))

  printf '\n══════════════════════════════════════════════════\n' >&2
  printf '  dotfiles install complete\n' >&2
  printf '  %d modules installed (%ds)\n' "${_CORE_MODULES_OK}" "${elapsed}" >&2
  if [[ ${#_CORE_MODULES_FAILED[@]} -gt 0 ]]; then
    printf '  %d module(s) failed: %s\n' "${#_CORE_MODULES_FAILED[@]}" "${_CORE_MODULES_FAILED[*]}" >&2
  fi
  if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
    printf '  Log: %s\n' "${DOTFILES_LOG_FILE}" >&2
  fi
  printf '══════════════════════════════════════════════════\n' >&2
}
```

- [ ] **Step 4: Wire timing start and final summary into `install.sh`**

In `install.sh`'s `main()` function, add timing start after `core::parse_args`:

```bash
  core::parse_args "$@"
  _CORE_INSTALL_START="$(date +%s)"
```

Replace the last two lines of `main()` (the `core::print_summary` and `core::log INFO "Install complete."` lines) with:

```bash
  core::summary_file "${HOME}/.zprofile"
  core::summary_file "${HOME}/.zshrc"

  core::print_summary
  core::print_final_summary
```

- [ ] **Step 5: Verify the summary renders**

```bash
cd /Volumes/Code/dotfiles && bash -c '
source lib/modules.sh; source lib/detect.sh; source lib/core.sh
DOTFILES_LOG_FILE=/tmp/test-summary.log
_CORE_INSTALL_START="$(date +%s)"
_CORE_MODULES_OK=3
_CORE_MODULES_FAILED=(nvim)
sleep 1
core::print_final_summary
'
```

Expected: A bordered summary showing `3 modules installed (1s)` and `1 module(s) failed: nvim` with the log path.

- [ ] **Step 6: Commit**

```bash
git add lib/core.sh install.sh
git commit -m "feat: add module timing and final install summary

core::run_module now tracks per-module elapsed time and success/failure.
A new core::print_final_summary shows total modules, elapsed time,
any failures, and the log file path."
```

---

### Task 5: Migrate high-noise modules — nvim

**Files:**
- Modify: `modules/nvim.sh`

- [ ] **Step 1: Wrap noisy commands in `_nvim::install_deps`**

Replace the raw `go install` and `cargo install` lines (lines 28-31):

```bash
  # lazygit and tree-sitter-cli are not in apt/dnf.
  # golang and rust modules run before nvim, so go and cargo are on PATH.
  core::run_cmd "Installing lazygit" go install github.com/jesseduffield/lazygit@latest
  core::summary "    ✓ lazygit installed via go"
  core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli
  core::summary "    ✓ tree-sitter-cli installed via cargo"
```

- [ ] **Step 2: Wrap noisy commands in `_nvim::install_from_src`**

Replace lines 47-51 (the git clone, git checkout, make, sudo make):

```bash
  core::run_cmd "Cloning neovim source" git clone https://github.com/neovim/neovim.git "${src_dir}"

  pushd "${src_dir}" >/dev/null
  core::run_cmd "Checking out stable branch" git checkout stable
  core::run_cmd "Building neovim" make CMAKE_BUILD_TYPE=RelWithDebInfo
  core::run_cmd "Installing neovim" sudo make install
  popd >/dev/null

  core::log INFO "Neovim built and installed from source (stable)"
```

- [ ] **Step 3: Wrap noisy commands in `_nvim::clone_config`**

Replace line 115 (the `git clone` call):

```bash
  core::run_cmd "Cloning neovim config" git clone --branch "${branch}" "${repo}" ~/.config/nvim
  core::log INFO "Cloned neovim config to ~/.config/nvim"
  core::summary "    ✓ config → ~/.config/nvim (cloned)"
```

- [ ] **Step 4: Wrap `core::pkg_install` in `_nvim::install_deps`**

Replace lines 17-24 (the case statement body):

```bash
_nvim::install_deps() {
  case "${DOTFILES_OS}" in
  mac)
    core::run_cmd "Installing nvim dependencies" core::pkg_install ripgrep fd node shfmt shellcheck
    ;;
  linux)
    core::run_cmd "Installing nvim dependencies" core::pkg_install ripgrep fd-find nodejs npm shfmt shellcheck
    ;;
  esac

  # lazygit and tree-sitter-cli are not in apt/dnf.
  # golang and rust modules run before nvim, so go and cargo are on PATH.
  core::run_cmd "Installing lazygit" go install github.com/jesseduffield/lazygit@latest
  core::summary "    ✓ lazygit installed via go"
  core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli
  core::summary "    ✓ tree-sitter-cli installed via cargo"
}
```

- [ ] **Step 5: Wrap `core::pkg_install` in `_nvim::install_nvim` mac case**

Replace line 67 inside the mac case:

```bash
  mac)
    core::run_cmd "Installing neovim via brew" core::pkg_install neovim
    ;;
  ```

And replace line 85 inside the pkg manager install choice:

```bash
      1)
        core::run_cmd "Installing neovim" core::pkg_install neovim
        return
        ;;
```

- [ ] **Step 6: Commit**

```bash
git add modules/nvim.sh
git commit -m "feat(nvim): wrap noisy commands with core::run_cmd

Suppresses cargo compile, make build, git clone, and pkg_install
output in normal mode. All output captured to log file."
```

---

### Task 6: Migrate high-noise modules — sheldon

**Files:**
- Modify: `modules/sheldon.sh`

- [ ] **Step 1: Wrap cargo install**

Replace line 29 (`cargo install sheldon --locked`):

```bash
    core::run_cmd "Installing sheldon" cargo install sheldon --locked
```

- [ ] **Step 2: Wrap sheldon init and lock commands**

Replace lines 38-39 (`printf 'y\n' | sheldon init --shell zsh`):

```bash
  core::run_cmd "Initializing sheldon" bash -c 'printf "y\n" | sheldon init --shell zsh'
```

Replace line 51 (`sheldon lock --update`):

```bash
  core::run_cmd "Locking sheldon plugins" sheldon lock --update
```

- [ ] **Step 3: Wrap sheldon add commands**

Replace lines 40-49 (the for loop with `sheldon add`):

```bash
  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    # zsh-completions must use fpath instead of source to avoid permission errors.
    if [[ "${name}" == "zsh-completions" ]]; then
      core::run_cmd "Adding plugin ${name}" sheldon add "${name}" --github "${plugin}" --apply fpath
    else
      core::run_cmd "Adding plugin ${name}" sheldon add "${name}" --github "${plugin}"
    fi
  done
```

- [ ] **Step 4: Commit**

```bash
git add modules/sheldon.sh
git commit -m "feat(sheldon): wrap noisy commands with core::run_cmd

Suppresses cargo compile and sheldon init/add/lock output in normal
mode. All output captured to log file."
```

---

### Task 7: Migrate high-noise modules — rust

**Files:**
- Modify: `modules/rust.sh`

- [ ] **Step 1: Wrap the rustup installer**

Replace line 22 (`curl ... | sh -s -- -y`):

```bash
    core::run_cmd "Installing rustup" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
```

- [ ] **Step 2: Commit**

```bash
git add modules/rust.sh
git commit -m "feat(rust): wrap rustup installer with core::run_cmd

Suppresses rustup installation output in normal mode."
```

---

### Task 8: Migrate high-noise modules — starship

**Files:**
- Modify: `modules/starship.sh`

- [ ] **Step 1: Wrap the starship installer**

Replace line 20 (`curl -sS https://starship.rs/install.sh | sh -s -- --yes`):

```bash
    core::run_cmd "Installing starship" bash -c 'curl -sS https://starship.rs/install.sh | sh -s -- --yes'
```

- [ ] **Step 2: Commit**

```bash
git add modules/starship.sh
git commit -m "feat(starship): wrap installer with core::run_cmd

Suppresses starship install script output in normal mode."
```

---

### Task 9: Migrate high-noise modules — golang

**Files:**
- Modify: `modules/golang.sh`

- [ ] **Step 1: Wrap curl download and tar extraction**

Replace lines 45-48 (the curl download, sudo rm, sudo tar, rm sequence):

```bash
  core::run_cmd "Downloading Go ${version}" curl -fsSL "${url}" -o "/tmp/${tarball}"
  sudo rm -rf /usr/local/go
  core::run_cmd "Extracting Go ${version}" sudo tar -C /usr/local -xzf "/tmp/${tarball}"
  rm "/tmp/${tarball}"
```

- [ ] **Step 2: Commit**

```bash
git add modules/golang.sh
git commit -m "feat(golang): wrap download/extract with core::run_cmd

Suppresses curl download and tar extraction output in normal mode."
```

---

### Task 10: Migrate remaining noisy modules — tmux, atuin, ssh

**Files:**
- Modify: `modules/tmux.sh`
- Modify: `modules/atuin.sh`
- Modify: `modules/ssh.sh`

- [ ] **Step 1: Wrap tmux git clone**

In `modules/tmux.sh`, replace line 14 (`core::pkg_install tmux`) and line 21 (the git clone):

```bash
install() {
  core::run_cmd "Installing tmux" core::pkg_install tmux

  # Manual installation per oh-my-tmux README.md
  # (section: "Manual installation `~/.config/tmux`")
  local clone_dir="${HOME}/.local/share/tmux/oh-my-tmux"
  local config_dir="${HOME}/.config/tmux"

  core::run_cmd "Cloning oh-my-tmux" git clone --single-branch https://github.com/gpakosz/.tmux.git "${clone_dir}"
  mkdir -p "${config_dir}"
  ln -s "${clone_dir}/.tmux.conf" "${config_dir}/tmux.conf"
  cp "${clone_dir}/.tmux.conf.local" "${config_dir}/tmux.conf.local"

  core::log INFO "oh-my-tmux installed"
  core::summary "    ✓ oh-my-tmux cloned to ~/.local/share/tmux/oh-my-tmux"
  core::summary "    ✓ config → ~/.config/tmux/tmux.conf (symlink)"
  core::summary "    ✓ config → ~/.config/tmux/tmux.conf.local (copied)"
}
```

- [ ] **Step 2: Wrap atuin cargo install**

In `modules/atuin.sh`, replace line 22 (`cargo install atuin --locked`):

```bash
    core::run_cmd "Installing atuin" cargo install atuin --locked
```

- [ ] **Step 3: Wrap ssh noisy commands**

In `modules/ssh.sh`, wrap the `core::pkg_install` call and the apt repo setup in `_ssh::install_packages`:

Replace line 19:

```bash
  core::run_cmd "Installing sshpass" core::pkg_install sshpass
```

Replace line 59:

```bash
  if [[ "${DOTFILES_PKG_MANAGER}" != "dnf" ]]; then
    core::run_cmd "Installing gh" core::pkg_install gh
  fi
```

- [ ] **Step 4: Commit**

```bash
git add modules/tmux.sh modules/atuin.sh modules/ssh.sh
git commit -m "feat(tmux,atuin,ssh): wrap noisy commands with core::run_cmd

Suppresses git clone, cargo install, and pkg_install output in
normal mode for tmux, atuin, and ssh modules."
```

---

### Task 11: Migrate bootstrap noisy commands

**Files:**
- Modify: `lib/bootstrap.sh`

- [ ] **Step 1: Wrap package installs in `bootstrap::zsh`**

In `bootstrap::zsh`, replace lines 31-33 (the apt/dnf install calls):

```bash
    linux)
      if command -v apt-get >/dev/null 2>&1; then
        core::run_cmd "Installing zsh" sudo apt-get install -y zsh
      elif command -v dnf >/dev/null 2>&1; then
        core::run_cmd "Installing zsh" sudo dnf install -y zsh
      else
```

- [ ] **Step 2: Wrap `bootstrap::dev_tools` package installs**

Replace lines 186-209 (the case body):

```bash
  case "${DOTFILES_PKG_MANAGER}" in
  brew)
    core::run_cmd "Installing dev tools" core::pkg_install cmake meson ninja gettext
    ;;
  apt)
    core::run_cmd "Installing dev tools" core::pkg_install git curl cmake meson ninja-build gettext \
      pkg-config libssl-dev libclang-dev build-essential
    ;;
  dnf)
    core::run_cmd "Installing dev tools" core::pkg_install git curl cmake meson ninja-build gettext \
      pkg-config openssl-devel clang-devel
    # @development-tools is a dnf group — check and install directly.
    if dnf group list --installed 2>/dev/null | grep -qi "development tools"; then
      core::log INFO "Already installed: @development-tools"
      core::summary "    ✓ @development-tools already installed"
    else
      core::run_cmd "Installing @development-tools" sudo dnf install -y @development-tools
      core::summary "    ✓ @development-tools installed via dnf"
    fi
    ;;
  *)
    core::log ERROR "Unsupported package manager: ${DOTFILES_PKG_MANAGER}"
    core::log ERROR "Supported: brew (macOS), apt (Debian/Ubuntu), dnf (Fedora/RHEL)"
    return 1
    ;;
  esac
```

- [ ] **Step 3: Commit**

```bash
git add lib/bootstrap.sh
git commit -m "feat(bootstrap): wrap noisy commands with core::run_cmd

Suppresses package manager output during zsh install and dev tools
setup in normal mode."
```

---

### Task 12: Apply same pattern to `uninstall.sh`

**Files:**
- Modify: `uninstall.sh`

- [ ] **Step 1: Add verbosity and log file initialization to `uninstall.sh`**

After the `readonly DOTFILES_ROOT` line (line 21), before the source lines, add:

```bash
DOTFILES_VERBOSITY="normal"
DOTFILES_LOG_FILE="/tmp/dotfiles-uninstall-$(date +%Y%m%d-%H%M%S).log"
```

- [ ] **Step 2: Add `--verbose` to uninstall.sh parse_args**

The `core::parse_args` already handles `--verbose` (modified in Task 1), so it works for `uninstall.sh` too since it sources `lib/core.sh`. No additional code needed.

- [ ] **Step 3: Add timing and final summary to `uninstall.sh`**

In `main()`, add start time after `core::parse_args`:

```bash
  core::parse_args "$@"
  _CORE_INSTALL_START="$(date +%s)"
```

Replace the last lines (`core::print_summary` and `core::log INFO "Uninstall complete."`) with:

```bash
  core::print_summary
  core::print_final_summary
```

- [ ] **Step 4: Update `core::usage` to mention both scripts**

No change needed — the `--verbose` flag description is generic enough for both.

- [ ] **Step 5: Commit**

```bash
git add uninstall.sh
git commit -m "feat: add verbosity and timing support to uninstall.sh

Mirrors install.sh's verbosity framework: --verbose flag, log file
collection, and final summary with timing."
```

---

### Task 13: End-to-end validation

**Files:**
- No new files; validation only

- [ ] **Step 1: Dry-run shellcheck on all modified files**

```bash
cd /Volumes/Code/dotfiles && shellcheck lib/core.sh lib/bootstrap.sh install.sh uninstall.sh modules/*.sh
```

Expected: No new warnings (some pre-existing SC2034 disables are expected in modules).

- [ ] **Step 2: Verify normal mode output is clean**

```bash
cd /Volumes/Code/dotfiles && ./install.sh --only git 2>&1 | head -30
```

Expected: Only `[INFO]` progress lines visible. No raw git config output. The git module is low-noise but confirms the framework doesn't break normal execution.

- [ ] **Step 3: Verify verbose mode passes output through**

```bash
cd /Volumes/Code/dotfiles && ./install.sh --verbose --only git 2>&1 | head -30
```

Expected: `[INFO]` lines plus any command output visible inline.

- [ ] **Step 4: Verify log file is created and populated**

```bash
ls -la /tmp/dotfiles-install-*.log | tail -1
wc -l /tmp/dotfiles-install-*.log | tail -1
```

Expected: Log file exists and has content.

- [ ] **Step 5: Commit any final fixes**

If shellcheck or testing revealed issues, fix and commit:

```bash
git add -A
git commit -m "fix: address shellcheck and integration issues from verbosity migration"
```
