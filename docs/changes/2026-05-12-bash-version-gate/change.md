# feature: bash version gate and bootstrap-macos.sh

Date: 2026-05-12
Type: feature
Files: bootstrap-macos.sh, install.sh, uninstall.sh, README.md, lib/bootstrap.sh

## Background

The project uses bash 4.3+ features (associative arrays, `[[ -v arr[k] ]]`).
macOS ships bash 3.2 system-wide and Apple never updates it. Without a guard,
users on a fresh Mac get cryptic syntax errors.

## What changed

- Added `bootstrap-macos.sh`: one-time script that installs Homebrew + modern
  bash on a fresh Mac (written in bash 3.2 compatible syntax)
- Added bash >= 4.3 version check at the top of install.sh and uninstall.sh
  (before any lib is sourced, bash 3.2 safe); exits with actionable error
- Updated README Prerequisites section with bash 4.3+ requirement and
  macOS-specific instructions
- Updated Quick Install section to show bootstrap-macos.sh step

## Why

Fail fast with a clear message instead of cryptic parse errors. The separate
bootstrap script avoids chicken-and-egg (can't use lib functions before bash
is upgraded, and can't upgrade bash without brew).
