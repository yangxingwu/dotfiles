# Module: nodejs

Node.js runtime managed by fnm (Fast Node Manager). Provides node, npm,
and automatic version switching via .node-version / .nvmrc files.

## What it installs

| Component | Method | Notes |
|---|---|---|
| fnm | `cargo install fnm` | Rust binary, Node version manager |
| Node.js LTS | `fnm install --lts` | Current LTS (22.x), includes npm |

## Configuration

Shell block in `~/.zprofile` (block ID: `nodejs`):

```bash
eval "$(fnm env --use-on-cd)"
```

This activates fnm's PATH management and enables automatic version switching
when entering a directory containing `.node-version` or `.nvmrc`.

## Usage after install

```bash
# Check versions
node -v
npm -v

# Install a specific Node version
fnm install 20
fnm use 20

# Set default version
fnm default 22

# Per-project version pinning
echo "22" > .node-version
# fnm auto-switches when you cd into this directory (--use-on-cd)
```

## Module hooks

| Hook | Action |
|---|---|
| `install` | install fnm (cargo), install Node LTS, write shell block |
| `uninstall` | remove shell block, remove ~/.local/share/fnm (Node versions + global packages) |

## Notes

- npm is bundled with Node.js — no separate package needed.
- fnm binary (~/.cargo/bin/fnm) is NOT removed on uninstall (consistent with
  other cargo-installed tools in this project).
- npm global packages (e.g. `npm install -g neovim`) live under the fnm-managed
  Node prefix, not system paths — no sudo needed on any platform.
- Dependencies: rust module (provides cargo).

## `--mirror-cn` flag

When `./install.sh --mirror-cn` is used, the nodejs module sets the npm registry
to `https://registry.npmmirror.com` for faster package downloads in China.
