# cli-tools 模块实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 新增 `modules/cli-tools.sh`，通过 cargo/pkg_install 安装现代 CLI 替代工具（bat, eza, rg, fd, jq, tealdeer），配置 bat catppuccin-mocha 主题，并将 rg/fd 的归属从 nvim 模块移出。

**架构：** 单一模块 `cli-tools.sh`，遵循现有模块接口契约。Rust 工具通过 `cargo install` 安装（由 `core::check_installed` 守卫实现幂等）。jq 通过 `core::pkg_install`。bat catppuccin 主题从 GitHub 下载，网络失败时回退到内置主题。

**技术栈：** Bash（模块接口）、cargo、core::pkg_install、curl（主题下载）。

**提交策略：** 所有变更最终合并为一个 commit。

---

### 任务 1: 在模块列表中加入 cli-tools

**文件：**
- 修改: `lib/modules.sh:8-24`

- [ ] **步骤 1: 在 DOTFILES_MODULES 数组中插入 cli-tools**

在 `lib/modules.sh` 中，将 `cli-tools` 加在 `golang` 之后、`fzf` 之前：

```bash
DOTFILES_MODULES=(
  homebrew             # mac only: .zprofile shellenv (must be first for brew PATH)
  font-hack-nerd-font
  git
  ssh              # after git: identity before connectivity
  rust             # before nvim: cargo is required for tree-sitter-cli
  golang           # before nvim: go install lazygit
  cli-tools        # after rust/golang: cargo tools; before fzf: fzf preview uses bat/fd
  fzf              # before zoxide: zi interactive mode uses fzf
                   # before sheldon: sheldon's fzf-tab plugin requires the fzf binary
  zoxide
  sheldon
  atuin            # after rust (cargo), after sheldon (replaces its history-substring-search)
  starship
  ghostty          # after font/sheldon/zoxide/starship: config assumes these are installed
  nvim             # after rust (cargo) and golang (go install lazygit)
  tmux
)
```

---

### 任务 2: 创建 modules/cli-tools.sh

**文件：**
- 新建: `modules/cli-tools.sh`

- [ ] **步骤 1: 编写完整模块文件**

```bash
#!/usr/bin/env bash
# modules/cli-tools.sh — Modern CLI replacements
# Platform: all
#
# Installed tools:
#   bat       — cat replacement with syntax highlighting (Rust)
#   eza       — ls replacement with git integration (Rust)
#   ripgrep   — grep replacement, fast (Rust)
#   fd-find   — find replacement, user-friendly syntax (Rust)
#   jq        — JSON processor (C; installed via package manager)
#   tealdeer  — tldr client, concise command examples (Rust)
#
# Optional tools NOT installed by this module (install manually if desired):
#   dust      — du replacement, tree visualization — cargo install du-dust
#   duf       — df replacement, colored table output — available in brew/apt/dnf
#   hyperfine — command benchmarking — cargo install hyperfine
#   yazi      — terminal file manager — cargo install yazi-fm yazi-cli
#   btop      — htop replacement, system monitor — available in brew/apt/dnf
#   tokei     — code line counter — cargo install tokei
#   procs     — ps replacement — cargo install procs
#   bandwhich — network bandwidth monitor — cargo install bandwhich
#   bottom    — system monitor TUI — cargo install bottom
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="cli-tools"
MODULE_DESC="Modern CLI replacements (bat, eza, rg, fd, jq, tldr)"
MODULE_PLATFORM="all"

_CLI_BAT_THEME_URL="https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme"
_CLI_BAT_THEME_NAME="Catppuccin Mocha"
_CLI_BAT_FALLBACK_THEME="OneHalfDark"

# Install Rust-based CLI tools via cargo.
_cli::install_cargo_tools() {
  local -a crates=("bat" "eza" "ripgrep" "fd-find" "tealdeer")
  local -a binaries=("bat" "eza" "rg" "fd" "tldr")
  local i

  for i in "${!crates[@]}"; do
    if core::check_installed "${binaries[${i}]}"; then
      core::log INFO "Already installed: ${binaries[${i}]}"
      core::summary "    ✓ ${binaries[${i}]} already installed"
    else
      core::run_cmd "Installing ${crates[${i}]}" cargo install "${crates[${i}]}"
      core::summary "    ✓ ${binaries[${i}]} installed via cargo"
    fi
  done
}

# Install tools that are not available via cargo.
_cli::install_pkg_tools() {
  core::run_cmd "Installing jq" core::pkg_install jq
}

# Download catppuccin-mocha theme for bat and write config.
_cli::write_bat_config() {
  local config_dir
  config_dir="$(bat --config-dir)"
  local themes_dir="${config_dir}/themes"
  local config_file="${config_dir}/config"
  local theme_file="${themes_dir}/Catppuccin Mocha.tmTheme"

  mkdir -p "${themes_dir}"

  # Download theme if not already present.
  if [[ ! -f "${theme_file}" ]]; then
    if curl --connect-timeout 10 --max-time 30 -fsSL "${_CLI_BAT_THEME_URL}" -o "${theme_file}"; then
      core::log INFO "Downloaded bat theme: ${_CLI_BAT_THEME_NAME}"
    else
      core::log WARN "Failed to download bat theme — using fallback ${_CLI_BAT_FALLBACK_THEME}"
      printf '%s\n' "--theme=\"${_CLI_BAT_FALLBACK_THEME}\"" >"${config_file}"
      core::summary "    ✓ bat config → ${config_file} (fallback theme)"
      return 0
    fi
  fi

  bat cache --build >/dev/null 2>&1
  printf '%s\n' "--theme=\"${_CLI_BAT_THEME_NAME}\"" >"${config_file}"
  core::log INFO "Wrote bat config: ${config_file}"
  core::summary "    ✓ bat config → ${config_file} (${_CLI_BAT_THEME_NAME})"
}

# Populate tealdeer page cache for offline usage.
_cli::update_tealdeer_cache() {
  if tldr --update >/dev/null 2>&1; then
    core::log INFO "Updated tealdeer page cache"
    core::summary "    ✓ tealdeer cache updated"
  else
    core::log WARN "Failed to update tealdeer cache (network issue?) — skipping"
    core::summary "    — tealdeer cache update skipped (network)"
  fi
}

install() {
  _cli::install_cargo_tools
  _cli::install_pkg_tools
  _cli::write_bat_config
  _cli::update_tealdeer_cache
}

uninstall() {
  local config_dir
  config_dir="$(bat --config-dir 2>/dev/null)" || config_dir="${HOME}/.config/bat"

  rm -f "${config_dir}/config"
  rm -f "${config_dir}/themes/Catppuccin"*
  bat cache --build >/dev/null 2>&1 || true

  core::log INFO "Removed bat config and theme"
  core::summary "    ✓ removed bat config and catppuccin theme"
}
```

---

### 任务 3: 精简 nvim 模块

**文件：**
- 修改: `modules/nvim.sh:16-32`

- [ ] **步骤 1: 从 _nvim::install_deps() 中移除 rg/fd**

将当前的：

```bash
_nvim::install_deps() {
  case "${DOTFILES_OS}" in
  mac)
    core::run_cmd "Installing nvim dependencies" core::pkg_install ripgrep fd node shfmt shellcheck
    ;;
  linux)
    core::run_cmd "Installing nvim dependencies" core::pkg_install ripgrep fd-find nodejs npm shfmt shellcheck
    ;;
  esac

  # lazygit and tree-sitter-cli are not in apt/dnf.
  # golang and rust modules run before nvim, so go and cargo are on PATH.
  core::run_cmd "Installing lazygit" go install github.com/jesseduffield/lazygit@latest
  core::summary "    ✓ lazygit installed via go"
  core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli
  core::summary "    ✓ tree-sitter-cli installed via cargo"
}
```

改为：

```bash
_nvim::install_deps() {
  # rg and fd are provided by the cli-tools module (runs before nvim).
  case "${DOTFILES_OS}" in
  mac)
    core::run_cmd "Installing nvim dependencies" core::pkg_install node shfmt shellcheck
    ;;
  linux)
    core::run_cmd "Installing nvim dependencies" core::pkg_install nodejs npm shfmt shellcheck
    ;;
  esac

  # lazygit and tree-sitter-cli are not in apt/dnf.
  # golang and rust modules run before nvim, so go and cargo are on PATH.
  core::run_cmd "Installing lazygit" go install github.com/jesseduffield/lazygit@latest
  core::summary "    ✓ lazygit installed via go"
  core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli
  core::summary "    ✓ tree-sitter-cli installed via cargo"
}
```

唯一变更：从 pkg_install 调用中移除 `ripgrep fd`（mac）和 `ripgrep fd-find`（linux）。

---

### 任务 4: 更新集成测试

**文件：**
- 修改: `tests/test_install.sh`

- [ ] **步骤 1: 在 Phase 2 中添加 cli-tools 安装断言**

在现有的 `assert_command starship` 行（约第 89 行）之后添加：

```bash
# cli-tools
assert_command bat
assert_command eza
assert_command rg
assert_command fd
assert_command jq
assert_command tldr
assert_file_exists "${HOME}/.config/bat/config"
assert_file_contains "${HOME}/.config/bat/config" "Catppuccin Mocha"
```

- [ ] **步骤 2: 在 Phase 4 中添加 cli-tools 卸载断言**

在现有的 `assert_file_not_contains "${HOME}/.gitconfig" "yangxingwu"` 行（约第 194 行）之后添加：

```bash
# cli-tools uninstall
assert_file_missing "${HOME}/.config/bat/config"
```

---

### 任务 5: 更新 README.md

**文件：**
- 修改: `README.md`

- [ ] **步骤 1: 在模块表格中添加 cli-tools**

在 Modules 表格中，`golang` 行之后、`fzf` 行之前插入：

```markdown
| `cli-tools` | all | Modern CLI tools: bat, eza, rg, fd, jq, tldr (catppuccin theme) |
```

---

### 任务 6: 更新 todo.md

**文件：**
- 修改: `docs/changes/2026-05-12-project-gaps/todo.md`

- [ ] **步骤 1: 将 "Modern CLI Tools" 项标记为完成**

在 "P1 — Core CLI Experience" 部分，将 "Modern CLI Tools" 小节的所有 `- [ ]` 改为 `- [x]`。

---

### 任务 7: 验证与提交

- [ ] **步骤 1: 对新模块运行 shellcheck**

运行: `shellcheck modules/cli-tools.sh`
预期: 无错误（SC2034 已由 disable 指令抑制）。

- [ ] **步骤 2: 运行 shfmt 格式化**

运行: `shfmt -w modules/cli-tools.sh`

- [ ] **步骤 3: 验证模块列表正确**

运行: `./install.sh --list`
预期输出中 `cli-tools` 应出现在 `golang` 和 `fzf` 之间。

- [ ] **步骤 4: 创建单个 commit**

```bash
git add lib/modules.sh modules/cli-tools.sh modules/nvim.sh \
        tests/test_install.sh README.md \
        docs/changes/2026-05-12-project-gaps/todo.md
git commit -m "feat: add cli-tools module (bat, eza, rg, fd, jq, tealdeer)

New module installing modern CLI replacements via cargo:
- bat (cat with syntax highlighting, catppuccin-mocha theme)
- eza (ls with git/icons)
- ripgrep (fast grep)
- fd-find (user-friendly find)
- tealdeer (tldr command examples)
- jq (JSON processor, via package manager)

Includes bat catppuccin-mocha theme configuration with network-failure
fallback. Moves rg/fd ownership from nvim module to cli-tools (nvim
still uses them but no longer installs them).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```
