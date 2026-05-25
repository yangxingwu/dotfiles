# Module: git

Complete Git configuration: identity, modern workflow defaults, delta diff pager,
lazygit TUI, SSH commit signing, and global gitignore.

git itself is already installed by bootstrap (CLT on macOS, dev_tools on Linux).

## Identity

Git identity is **not hardcoded**. Resolution order:

1. Existing `git config --global` (reuse if already set)
2. Interactive prompt (if TTY available)
3. Skip silently (non-interactive, e.g. CI with pre-configured git config)

Uninstall does not remove identity — it is user data, not dotfiles-managed config.

## Module hooks

| Hook | Action |
|---|---|
| `install` | configure identity; install delta (cargo) + lazygit (go); clone catppuccin theme + write lazygit config + shell alias; write global gitignore; set workflow/delta/signing git config; push SSH signing key to GitHub |
| `uninstall` | remove workflow/delta/signing git config; remove lazygit config + theme clone + alias; remove global gitignore; retain identity + delta/lazygit binaries |

## Tools installed

| Tool | Install method | Purpose |
|---|---|---|
| delta | `cargo install git-delta` | Syntax-highlighted diff pager (unified format with syntax highlighting) |
| lazygit | `go install lazygit@latest` | Terminal UI for git |

## Configuration files

| File | Content |
|---|---|
| `~/.gitconfig` | Identity, workflow, delta, signing config |
| `~/.config/lazygit/config.yml` | Nerd Font icons setting |
| `~/.local/share/lazygit/catppuccin/` | Cloned catppuccin/lazygit theme repo |
| `~/.config/git/ignore` | Global gitignore (OS/editor artifacts) |
| `~/.zshrc` block `lazygit` | Alias merging catppuccin theme via --use-config-file |

## Git config summary

**Workflow:** init.defaultBranch=main, pull.rebase, rebase.autoStash,
push.autoSetupRemote, merge.conflictstyle=zdiff3, rerere.enabled, core.editor=nvim

**Diff:** diff.algorithm=histogram, diff.colorMoved=default

**Delta:** core.pager=delta, interactive.diffFilter, delta.navigate=true,
delta.dark=true

**URL rewrite:** `url."git@github.com:".insteadOf "https://github.com/"` — all
GitHub HTTPS URLs automatically use SSH

**Signing:** commit.gpgsign, tag.gpgsign, gpg.format=ssh,
user.signingkey=~/.ssh/id_ed25519.pub

**Gitignore:** core.excludesFile=~/.config/git/ignore

**Performance:** core.untrackedcache=true (global), core.fsmonitor intentionally
NOT set globally (see below)

## fsmonitor guide

`core.fsmonitor=true` enables a built-in daemon that watches filesystem events
via FSEvents (macOS) / inotify (Linux), so `git status` only stat's changed
files. Huge speedup on large repos (80k+ files), but each daemon costs ~12
threads and ~5 MB RSS and **never exits** once started.

### Why NOT global

If enabled globally, any tool that touches git repos (e.g. Neovim lazy.nvim
syncing 40+ plugins) spawns 40+ persistent daemons. After hours of idle, macOS
memory-compresses their pages. Next `git status` must decompress/page-in the
daemon before it can respond — easily exceeds Starship's 500ms timeout,
producing `Executing command "/usr/bin/git" timed out` warnings.

### Recommended usage

Enable per-repo only on large codebases where `git status` is noticeably slow:

```bash
# Enable on a specific large repo
git -C /path/to/large-repo config core.fsmonitor true

# Verify daemon is running
git -C /path/to/large-repo fsmonitor--daemon status

# Stop daemon for a repo
git -C /path/to/large-repo fsmonitor--daemon stop

# Kill all daemons system-wide (useful for cleanup)
pkill -f 'fsmonitor--daemon'
```

Good candidates: repos with 10k+ tracked files (Linux kernel, Chromium, large
monorepos). Bad candidates: small repos (<1k files), read-only clones (package
manager plugins), repos you rarely touch.

## Notes

- Module runs after ssh (needs SSH key for signing), rust (needs cargo for
  delta), and golang (needs go for lazygit).
- SSH signing key is pushed to GitHub as type "signing" (separate from the
  authentication key pushed by the ssh module). View at:
  - CLI: `gh ssh-key list` (type column shows `signing`)
  - Web: https://github.com/settings/keys → "Signing Keys" section
- lazygit was previously installed by the nvim module; ownership moved here.
- lazygit catppuccin theme is loaded via `--use-config-file` merge at launch
  (see https://github.com/catppuccin/lazygit#usage). Update theme with
  `cd ~/.local/share/lazygit/catppuccin && git pull`.
