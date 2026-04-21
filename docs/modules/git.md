# Module: git

Git global configuration and a shared hooks directory wired up via `core.hooksPath`.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/git/gitconfig` | `~/.gitconfig` | all |
| `config/git/git-hooks/` | `~/.git-hooks/` | all |

## Dependencies

| Platform | Packages |
|---|---|
| macOS | `git` |
| Linux | `git` |

## Notes

`post_install` runs `git config --global core.hooksPath ~/.git-hooks` so every
repository on the machine automatically picks up the shared hooks directory without
per-repo configuration.

Add hook scripts to `config/git/git-hooks/` and make them executable. The installer
symlinks the whole directory, so new hooks are picked up automatically on the next
`install.sh` run.
