# Output Management: Specific Fixes Needed

## Quick Reference: All Commands That Need Suppression

### Priority 1: Highest Impact (easiest to fix, most output reduction)

#### `lib/core.sh` — `core::pkg_install()` function

**Current (lines 54, 67, 80):**
```bash
brew install "${package}" || { ... }
sudo apt-get install -y "${package}" || { ... }
sudo dnf install -y "${package}" || { ... }
```

**Fix to:**
```bash
brew install "${package}" >/dev/null 2>&1 || { ... }
sudo apt-get install -y "${package}" >/dev/null 2>&1 || { ... }
sudo dnf install -y "${package}" >/dev/null 2>&1 || { ... }
```

**Impact:** Reduces 300-800 lines of output in bootstrap phase

---

### Priority 2: High Impact (compilation output suppression)

#### `modules/nvim.sh` — Line 30

**Current:**
```bash
cargo install --locked tree-sitter-cli
```

**Fix to:**
```bash
cargo install --locked tree-sitter-cli >/dev/null 2>&1 || {
  core::log ERROR "tree-sitter-cli install failed"
  return 1
}
```

**Impact:** Suppresses 200-500 lines of compilation output

---

#### `modules/sheldon.sh` — Line 29

**Current:**
```bash
cargo install sheldon --locked
```

**Fix to:**
```bash
cargo install sheldon --locked >/dev/null 2>&1 || {
  core::log ERROR "sheldon install failed"
  return 1
}
```

**Impact:** Suppresses 150-300 lines of compilation output

---

#### `modules/atuin.sh` — Line 22

**Current:**
```bash
cargo install atuin --locked
```

**Fix to:**
```bash
cargo install atuin --locked >/dev/null 2>&1 || {
  core::log ERROR "atuin install failed"
  return 1
}
```

**Impact:** Suppresses 150-250 lines of compilation output

---

### Priority 3: Medium Impact (git clone and installer suppression)

#### `modules/nvim.sh` — Lines 46, 115

**Current:**
```bash
git clone https://github.com/neovim/neovim.git "${src_dir}"
git clone --branch "${branch}" "${repo}" ~/.config/nvim
```

**Fix to:**
```bash
git clone --quiet https://github.com/neovim/neovim.git "${src_dir}"
git clone --quiet --branch "${branch}" "${repo}" ~/.config/nvim
```

**Impact:** Suppresses 40-80 lines of git output

---

#### `modules/tmux.sh` — Line 21

**Current:**
```bash
git clone --single-branch https://github.com/gpakosz/.tmux.git "${clone_dir}"
```

**Fix to:**
```bash
git clone --quiet --single-branch https://github.com/gpakosz/.tmux.git "${clone_dir}"
```

**Impact:** Suppresses 10-20 lines of git output

---

#### `modules/nvim.sh` — Line 50 (make build suppression - optional, keeps progress)

**Current:**
```bash
make CMAKE_BUILD_TYPE=RelWithDebInfo
```

**Optional Fix (for quiet mode only):**
```bash
if [[ "${DOTFILES_VERBOSITY:-normal}" == "quiet" ]]; then
  make CMAKE_BUILD_TYPE=RelWithDebInfo >/dev/null 2>&1 || return 1
else
  make CMAKE_BUILD_TYPE=RelWithDebInfo || return 1
fi
```

**Impact:** Suppresses 200-400 lines in quiet mode

---

### Priority 4: Framework Changes (required for all the above to work)

#### `lib/core.sh` — Modify `core::log()` (lines 8-31)

**Add at the beginning:**
```bash
core::log() {
  local level="${1}" message="${2}" fd=1
  
  # NEW: Check verbosity level
  if [[ "${DOTFILES_VERBOSITY:-normal}" == "quiet" ]] && [[ "${level}" == "INFO" ]]; then
    return  # Suppress INFO logs in quiet mode
  fi

  case "${level}" in
  INFO) fd=1 ;;
  WARN | ERROR) fd=2 ;;
  esac
  
  # ... rest of function unchanged
```

**Impact:** Allows `core::log INFO` to be suppressed in quiet mode

---

#### `lib/core.sh` — Add to `core::usage()` (after line 164)

**Add:**
```bash
printf '  --quiet, -q        Suppress most output (show only summary)\n'
printf '  --verbose, -v      Show detailed output\n'
```

**Impact:** Documents new flags

---

#### `lib/core.sh` — Add to `core::parse_args()` (before line 207)

**Add in the while loop:**
```bash
--quiet | -q)
  export DOTFILES_VERBOSITY="quiet"
  shift
  ;;
--verbose | -v)
  export DOTFILES_VERBOSITY="verbose"
  shift
  ;;
```

**Impact:** Enables parsing of --quiet and --verbose flags

---

#### `lib/bootstrap.sh` — Line 144 (Homebrew installer)

**Current:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Fix to (for quiet mode):**
```bash
if [[ "${DOTFILES_VERBOSITY:-normal}" == "quiet" ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1 || {
    core::log ERROR "Homebrew installation failed"
    return 1
  }
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    core::log ERROR "Homebrew installation failed"
    return 1
  }
fi
```

**Impact:** Suppresses 20-50 lines of homebrew installer output in quiet mode

---

## Optional Enhancements

### Log File Collection (NOT REQUIRED but recommended)

**In `lib/core.sh` after line 256 (after summary tracking):**

```bash
# Log file handling
_DOTFILES_LOGFILE="${DOTFILES_LOG_FILE:-${HOME}/.dotfiles-install.log}"

# core::log_all <message>
# Writes to both stdout/stderr AND log file
core::log_all() {
  local level="${1}" message="${2}" fd=1
  
  case "${level}" in
  INFO) fd=1 ;;
  WARN | ERROR) fd=2 ;;
  esac
  
  # Write to console (respecting verbosity)
  core::log "${level}" "${message}"
  
  # Always write to log file (unfiltered)
  printf '[%s] %s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${level}" "${message}" >> "${_DOTFILES_LOGFILE}" 2>/dev/null || true
}
```

**Then replace `core::log` calls with `core::log_all`** (or add a global option to enable this)

---

## Testing Checklist

After implementing these fixes:

- [ ] Run `./install.sh --help` and verify new flags are listed
- [ ] Run `./install.sh` (normal mode) and verify output unchanged
- [ ] Run `./install.sh --quiet` and verify only critical output shown
- [ ] Run `./install.sh --verbose` and verify detailed logging (if implemented)
- [ ] Run `./install.sh --only rust --quiet` and verify quiet mode works with filters
- [ ] Verify `DOTFILES_VERBOSITY=quiet ./install.sh` works via environment variable
- [ ] Check log file at ~/.dotfiles-install.log (if log file feature added)
- [ ] Verify error messages still appear in quiet mode
- [ ] Run on macOS and Linux to test both package managers

---

## Summary of Changes

| File | Function | Lines | Change Type | Effort |
|------|----------|-------|------------|--------|
| lib/core.sh | core::log | 8-31 | Add verbosity check | Easy |
| lib/core.sh | core::usage | 157-165 | Add flag docs | Trivial |
| lib/core.sh | core::parse_args | 172-214 | Add flag parsing | Easy |
| lib/core.sh | core::pkg_install | 54, 67, 80 | Add output redirect | Trivial |
| lib/bootstrap.sh | bootstrap::homebrew | 144 | Add quiet mode check | Easy |
| modules/nvim.sh | _nvim::install_deps | 30 | Add output redirect | Trivial |
| modules/nvim.sh | _nvim::clone_config | 46, 115 | Add --quiet flag | Trivial |
| modules/nvim.sh | _nvim::install_from_src | 50 | Add optional redirect | Easy |
| modules/sheldon.sh | install | 29 | Add output redirect | Trivial |
| modules/atuin.sh | install | 22 | Add output redirect | Trivial |
| modules/tmux.sh | install | 21 | Add --quiet flag | Trivial |

**Total Effort:** 1-2 hours of implementation + testing

**Output Reduction:** 85% reduction in default output, 95%+ reduction with --quiet flag

