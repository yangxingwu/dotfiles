# Module: cli-tools

Modern CLI replacements installed via cargo (Rust tools) and package manager (jq).

## Module hooks

| Hook | Action |
|---|---|
| `install` | install bat, eza, ripgrep, fd-find, tealdeer via cargo; install jq via pkg manager; write bat config (catppuccin-mocha theme); update tealdeer page cache |
| `uninstall` | remove bat config file (binaries are preserved) |

## Installed tools

| Tool | Binary | Replaces | Language |
|---|---|---|---|
| bat | `bat` | cat | Rust |
| eza | `eza` | ls | Rust |
| ripgrep | `rg` | grep | Rust |
| fd-find | `fd` | find | Rust |
| jq | `jq` | — (JSON processor) | C |
| tealdeer | `tldr` | man (concise examples) | Rust |

## Configuration

- `~/.config/bat/config` — sets `--theme="Catppuccin Mocha"` (built-in theme
  since bat 0.25+, written to bat's native config file)

## Notes

- All Rust tools use `cargo install` — requires the `rust` module to run first.
- ripgrep and fd were previously installed by the nvim module; ownership moved
  here so they are available even with `--skip nvim`.
- tealdeer runs `tldr --update` on install to populate the page cache; network
  failure is non-fatal (logged as WARN, continues).
- This module runs before fzf in module order — fzf preview commands can use
  bat and fd once configured (separate task).

## Optional tools (not installed)

Listed in the module header comment for manual installation:

| Tool | Purpose | Install |
|---|---|---|
| dust | du replacement (tree visualization) | `cargo install du-dust` |
| duf | df replacement (colored tables) | brew/apt/dnf |
| hyperfine | command benchmarking | `cargo install hyperfine` |
| yazi | terminal file manager | `cargo install yazi-fm yazi-cli` |
| btop | htop replacement (system monitor) | brew/apt/dnf |
| tokei | code line counter | `cargo install tokei` |
| procs | ps replacement | `cargo install procs` |
| bandwhich | network bandwidth monitor | `cargo install bandwhich` |
| bottom | system monitor TUI | `cargo install bottom` |
