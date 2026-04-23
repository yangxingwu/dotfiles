# Module: tmux

tmux configuration using [oh-my-tmux](https://github.com/gpakosz/.tmux) as the base,
with a local override file for machine-specific settings. The upstream project is
installed via its official `install.sh` one-liner.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/tmux/tmux.conf.local` | `~/.config/tmux/tmux.conf.local` | all |

`~/.config/tmux/tmux.conf` and `~/.config/tmux/.tmux/` are created by oh-my-tmux's
upstream installer — they are not in our `LINKS`.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install tmux`; run oh-my-tmux's upstream installer |
| `uninstall` | remove `~/.config/tmux/.tmux/` and the `~/.config/tmux/tmux.conf` symlink |

## install()

Steps:

1. `core::pkg_install tmux`.
2. If `~/.config/tmux/.tmux/.git` already exists, skip the rest (idempotent).
3. `mkdir -p ~/.config/tmux/` so the upstream installer picks the XDG path rather than
   the home-directory fallback.
4. `curl -fsSL "${_TMUX_INSTALL_URL}" | bash` — oh-my-tmux clones itself to
   `~/.config/tmux/.tmux/`, creates the `tmux.conf` symlink, and `cp`'s its starter
   `tmux.conf.local`.
5. Remove that starter `tmux.conf.local` (only if it is still a real file, not our
   symlink from a prior run) so the upcoming LINKS phase can install our repo copy
   without triggering a conflict prompt.

Constants:

| Constant | Value |
|---|---|
| `_TMUX_INSTALL_URL` | `https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh` |
| `_TMUX_CLONE_DIR` | `${HOME}/.config/tmux/.tmux` |

## uninstall()

- `rm -rf ~/.config/tmux/.tmux/` if it is a git checkout.
- `rm ~/.config/tmux/tmux.conf` if it is a symlink.

## Local overrides

`config/tmux/tmux.conf.local` is symlinked to `~/.config/tmux/tmux.conf.local`.
oh-my-tmux sources this file automatically, so machine-specific tweaks go here without
touching the upstream config.
