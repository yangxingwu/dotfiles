# Module: git

Complete Git configuration: identity, modern workflow defaults, delta diff pager,
lazygit TUI, SSH commit signing, and global gitignore.

git itself is already installed by bootstrap (CLT on macOS, dev_tools on Linux).

## Identity

Git identity is **not hardcoded**. Resolution order:

1. Environment variables: `DOTFILES_GIT_NAME` / `DOTFILES_GIT_EMAIL`
2. Interactive prompt (if TTY available)
3. Skip silently (non-interactive without env vars, e.g. CI)

Uninstall does not remove identity — it is user data, not dotfiles-managed config.

## Module hooks

| Hook | Action |
|---|---|
| `install` | configure identity; install delta (cargo) + lazygit (go); clone catppuccin theme + write lazygit config + shell alias; write global gitignore; set workflow/delta/signing git config; push SSH signing key to GitHub |
| `uninstall` | remove workflow/delta/signing git config; remove lazygit config + theme clone + alias; remove global gitignore; retain identity + delta/lazygit binaries |

## Tools installed

| Tool | Install method | Purpose |
|---|---|---|
| delta | `cargo install git-delta` | Syntax-highlighted, side-by-side diff pager |
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

**Delta:** core.pager=delta, interactive.diffFilter, delta.navigate,
delta.side-by-side, delta.line-numbers

**Signing:** commit.gpgsign, tag.gpgsign, gpg.format=ssh,
user.signingkey=~/.ssh/id_ed25519.pub

**Gitignore:** core.excludesFile=~/.config/git/ignore

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
