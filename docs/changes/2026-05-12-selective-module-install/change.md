# feature: selective module install/uninstall via --only and --skip

Date: 2026-05-12
Type: feature
Files: lib/core.sh, lib/modules.sh, install.sh, uninstall.sh, README.md

## Background

install.sh and uninstall.sh always processed all modules. On an already-configured
machine, users often need to install or uninstall a single module without running
the full suite.

## What changed

- Added `--only mod1,mod2` flag to process only specified modules
- Added `--skip mod1,mod2` flag to exclude specified modules
- Added `--list` / `-l` to print available module names
- Added `--help` / `-h` for usage information
- `--only` and `--skip` are mutually exclusive; both validate module names
- Introduced `DOTFILES_SELECTED_MODULES` (filtered copy of `DOTFILES_MODULES`)
- Added `modules::filter` in lib/modules.sh (validates + filters using associative arrays)
- Added `core::parse_args` in lib/core.sh (CLI parsing, delegates to modules::filter)
- install.sh and uninstall.sh share the same interface (symmetric)

## Why

Allows targeted module operations without touching unrelated modules. Bootstrap
always runs regardless of filtering to ensure module preconditions are met.
