# Module: git

Git global configuration and a shared hooks directory. `core.hooksPath` is declared
directly inside `config/git/gitconfig`, so every repository on the machine automatically
picks up the shared hooks directory without per-repo configuration.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/git/gitconfig` | `~/.gitconfig` | all |
| `config/git/git-hooks/` | `~/.git-hooks/` | all |

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install git` (both platforms) |
| `uninstall` | no-op |

## Notes

`core.hooksPath = ~/.git-hooks` is declared in the tracked `config/git/gitconfig` file
itself — no hook-time `git config --global` call is needed.

Add hook scripts to `config/git/git-hooks/` and make them executable. The installer
symlinks the whole directory, so new hooks are picked up automatically on the next
`install.sh` run.
