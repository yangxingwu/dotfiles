# Module: python

Python 3 runtime, pip package manager, venv support, and pipx for isolated
CLI tool installation.

## What it installs

| Package | macOS (brew) | Ubuntu (apt) | Fedora (dnf) |
|---|---|---|---|
| python3 | python3 | python3 | python3 |
| pip | (included) | python3-pip | python3-pip |
| venv | (included) | python3-venv | (included) |
| python command | (included) | python-is-python3 | (included) |
| pipx | pipx | pipx | pipx |

## Configuration

PATH block in `~/.zprofile` (block ID: `python`):

```bash
export PATH="${HOME}/.local/bin:${PATH}"
```

This covers both `pip install --user` binaries and `pipx install` binaries.

## Usage after install

```bash
# Install a CLI tool globally (isolated):
pipx install httpie
pipx install ruff

# Project dependencies (in a venv):
python -m venv .venv
source .venv/bin/activate
pip install flask
```

## Module hooks

| Hook | Action |
|---|---|
| `install` | install python3/pip/venv/pipx packages; write PATH block to ~/.zprofile |
| `uninstall` | remove PATH block from ~/.zprofile; packages retained |

## Notes

- pipx creates isolated venvs in `~/.local/share/pipx/venvs/` and symlinks
  binaries to `~/.local/bin/`.
- No pip.conf is written — `[install] user = true` conflicts with venv usage.
- No pyenv — system python3 is sufficient for script/tool use.
- Module has no dependencies (MODULE_DEPS is empty).
