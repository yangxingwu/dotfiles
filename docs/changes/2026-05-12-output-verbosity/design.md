# Output Verbosity Control

## Problem

Running `install.sh` produces 900-3,100+ lines of uncontrolled output from package
managers, cargo builds, make, git clones, and installer scripts. The noise drowns out
the important status messages from `core::log`, making it impossible to see what is
actually happening at a glance.

## Design

### Verbosity Levels

Two levels, controlled by a command-line flag:

| Level | Flag | Module progress (`core::log`) | Command output | On failure |
|-------|------|-------------------------------|----------------|------------|
| `normal` (default) | none | Show | Hidden (written to log file) | Tail 20 lines + log path |
| `verbose` | `-v` / `--verbose` | Show | Live passthrough | Same (already visible) |

Global variable: `DOTFILES_VERBOSITY` (`normal` or `verbose`).

### Log File

- Path: `/tmp/dotfiles-install-<YYYYMMDD-HHMMSS>.log`
- All command output is always written to the log file regardless of verbosity level.
- The log path is displayed in the final summary.

### `core::run_cmd` Function

New function in `lib/core.sh`. All noisy external commands are executed through it.

**Signature:**

```bash
# Execute a command with output control based on DOTFILES_VERBOSITY.
#
# Arguments:
#   $1       - Human-readable description (for progress/log display)
#   $2...$N  - Command and arguments to execute
#
# Returns: The command's exit code
core::run_cmd() {
  local description="$1"
  shift
  # ...
}
```

**Behavior by verbosity level:**

```
normal mode:
  [INFO] Compiling sheldon...      <- shown
  (cargo output -> log file only)
  [INFO] Done: Compiling sheldon (23.4s)   <- shown

verbose mode:
  [INFO] Compiling sheldon...      <- shown
  (cargo output -> terminal + log file via tee)
  [INFO] Done: Compiling sheldon (23.4s)   <- shown

On failure (any level):
  [ERROR] Failed: Compiling sheldon (exit 1, 23.4s)
  ── last 20 lines ──────────────────────────
  error[E0433]: failed to resolve...
  ...
  ──────────────────────────────────────────────
  Full log: /tmp/dotfiles-install-20260512-143022.log
```

**Implementation details:**

- Output capture: `cmd >> "${LOG_FILE}" 2>&1` (normal) or `cmd 2>&1 | tee -a "${LOG_FILE}"` (verbose)
- Timing: record start/end via `date +%s`, display elapsed seconds on completion
- Exit code preservation: use `PIPESTATUS[0]` for the tee pipeline case
- Nesting: safe to use in subshells

### `core::log` Changes

- In `normal` mode: behaves exactly as today (outputs to stderr) AND appends to log file.
- In `verbose` mode: same behavior.
- No quiet-mode suppression needed (quiet level removed from design).

### Final Summary

After all modules complete, display a summary regardless of verbosity:

```
======================================
  dotfiles install complete
  11 modules installed (47.3s)
  1 module failed: nvim
  Log: /tmp/dotfiles-install-20260512-143022.log
======================================
```

### `core::run_module` Changes

Add module-level timing and failure tracking to generate the final summary:

```bash
core::run_module() {
  local module="$1"
  local start_time end_time elapsed

  start_time="$(date +%s)"
  core::log INFO "Installing ${module}..."

  if install; then
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    core::log INFO "Done: ${module} (${elapsed}s)"
  else
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    core::log ERROR "Failed: ${module} (${elapsed}s)"
    # Track failed module for final summary
  fi
}
```

### Commands That Need Wrapping

Commands producing significant output that should go through `core::run_cmd`:

- `core::pkg_install ...` (package manager output)
- `cargo install ...`
- `make ...`
- `git clone ...`
- `curl | bash` style installers (rustup, starship)
- `rustup ...`

### Commands That Do NOT Need Wrapping

Commands with minimal or structurally useful output:

- `mkdir -p`, `ln -sf`, `chmod` (no output)
- `git config ...` (no output)
- Heredoc file writes
- `core::log` calls (already structured)

### `core::pkg_install` Decision

`core::pkg_install` does NOT internally suppress output. Module authors wrap it
with `core::run_cmd` when desired. This keeps `core::pkg_install` single-purpose
and allows grouping multiple package installs under one progress description.

### CI Considerations

No special CI handling needed. Since we use plain line-by-line output (no spinner,
no terminal control sequences), CI systems capture everything naturally. The `CI=true`
environment variable is not checked.

## Migration Strategy

Incremental, module-by-module:

1. **Phase 1 - Framework**: Implement `core::run_cmd`, log file initialization,
   `--verbose` flag parsing, final summary display.
2. **Phase 2 - High-noise modules**: Migrate nvim, sheldon, rust, starship, golang
   (these produce 80%+ of the noise).
3. **Phase 3 - Remaining modules**: Migrate other modules as needed.

Each module migration is independent — no big-bang required.
