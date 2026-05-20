# Module: rust

[Rust](https://www.rust-lang.org/) toolchain via rustup. Cross-platform.

## Module hooks

| Hook | Action |
|---|---|
| `install` | install rustup via official installer; source `~/.cargo/env`; write managed `rust` block to `~/.zprofile` |
| `uninstall` | remove `rust` block from `~/.zprofile`; remove `~/.cargo/config.toml` |

## `--mirror-cn` flag

When `./install.sh --mirror-cn` is used, the rust module configures
[rsproxy.cn](https://rsproxy.cn/) mirrors:
- rustup: `RUSTUP_DIST_SERVER` and `RUSTUP_UPDATE_ROOT` point to rsproxy.cn
- cargo: writes `~/.cargo/config.toml` with `replace-with = 'rsproxy-sparse'`
  (sparse registry protocol for faster index access in China)

## Notes

- Installed via `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
  (official rustup installer).
- `~/.cargo/env` must exist after install — hard error if absent.
- The managed `rust` block in `~/.zprofile` contains: `. "${HOME}/.cargo/env"`.
- Must run before nvim and sheldon (both need cargo).
