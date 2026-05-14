# cli-tools 模块设计

日期: 2026-05-14

## 概述

新增 `modules/cli-tools.sh` 模块，统一安装现代 CLI 替代工具；精简
`modules/nvim.sh`，将 rg/fd 移至 cli-tools（通用工具不应藏在编辑器模块里）。

git 模块重构（delta、lazygit、git config 增强）不在本次范围内，将单独设计。

## 动机

项目定位是"现代开发者一键开箱即用"，但当前：

- bat/eza/jq/tealdeer 完全缺失
- rg/fd 藏在 nvim 模块里（作为 LazyVim 依赖被安装），`--skip nvim` 则没有
- fzf 的 preview 功能依赖 bat 和 fd，但它们不在 fzf 之前安装

## 变更范围

| 文件 | 动作 | 说明 |
|------|------|------|
| `modules/cli-tools.sh` | 新建 | bat, eza, rg, fd, jq, tealdeer + bat 配置 |
| `modules/nvim.sh` | 精简 | 移除 rg/fd 安装逻辑（由 cli-tools 保证） |
| `lib/modules.sh` | 调整 | 插入 cli-tools 位置 |
| `tests/test_install.sh` | 更新 | 新增断言 |

## 模块顺序

```
homebrew → font → git → ssh → rust → golang → cli-tools → fzf → zoxide →
sheldon → atuin → starship → ghostty → nvim → tmux
```

关键约束：
- cli-tools 在 rust 之后（Rust 工具需要 cargo）
- cli-tools 在 fzf 之前（fzf preview 依赖 bat 和 fd）
- nvim 在 cli-tools 之后（nvim 假设 rg/fd 已在 PATH）

---

## cli-tools 模块详细设计

### 安装的工具

| 工具 | crate/包名 | 安装方式 | 用途 |
|------|-----------|---------|------|
| bat | `bat` | cargo install | cat 替代，语法高亮 |
| eza | `eza` | cargo install | ls 替代，git/icons 集成 |
| ripgrep | `ripgrep` | cargo install | grep 替代，速度快 |
| fd-find | `fd-find` | cargo install | find 替代，语法友好 |
| jq | `jq` | core::pkg_install | JSON 处理器（C 语言，只能包管理器） |
| tealdeer | `tealdeer` | cargo install | tldr 客户端，命令速查 |

### 可选工具（不安装，模块文件头部注释列出供参考）

在模块文件头部注释中列出以下工具，说明用途和安装命令，供用户按需手动添加：

- dust（du 替代，磁盘占用树状可视化）— `cargo install du-dust`
- duf（df 替代，磁盘空间彩色表格）— 各平台包管理器均有
- hyperfine（命令基准测试）— `cargo install hyperfine`
- yazi（终端文件管理器）— `cargo install yazi-fm yazi-cli`
- btop（进程监控，htop 替代）— 各平台包管理器均有
- tokei（代码行数统计）— `cargo install tokei`
- procs（ps 替代）— `cargo install procs`
- bandwhich（网络带宽监控）— `cargo install bandwhich`
- bottom（系统监控 TUI）— `cargo install bottom`

### 配置文件

**bat 主题配置** — `~/.config/bat/config`：

```
--theme="Catppuccin Mocha"
```

Catppuccin 主题安装流程：

1. 从 catppuccin/bat 仓库下载 .tmTheme 文件到 `$(bat --config-dir)/themes/`
2. 执行 `bat cache --build` 重建缓存
3. 写入 config 文件引用该主题

若网络不可达或下载失败，回退到 bat 内置主题（如 `OneHalfDark`）。

**tealdeer 缓存** — 首次安装后执行 `tldr --update` 拉取页面缓存。

### 模块接口

```bash
MODULE_NAME="cli-tools"
MODULE_DESC="Modern CLI replacements (bat, eza, rg, fd, jq, tldr)"
MODULE_PLATFORM="all"
```

### 内部结构

```bash
_cli::install_cargo_tools()     # bat, eza, ripgrep, fd-find, tealdeer
_cli::install_pkg_tools()       # jq (via core::pkg_install)
_cli::write_bat_config()        # 下载 catppuccin 主题 + ~/.config/bat/config
_cli::update_tealdeer_cache()   # tldr --update

install() {
  _cli::install_cargo_tools
  _cli::install_pkg_tools
  _cli::write_bat_config
  _cli::update_tealdeer_cache
}
```

### 幂等性

- cargo install：已安装则跳过（`core::check_installed`）
- jq：`core::pkg_install` 内部已幂等
- bat config：每次覆写（声明式，无副作用）
- tealdeer cache：重复 update 无害

### uninstall()

```bash
uninstall() {
  # 移除 bat 配置和主题
  rm -f "$(bat --config-dir 2>/dev/null)/config"
  rm -rf "$(bat --config-dir 2>/dev/null)/themes/Catppuccin"*
  bat cache --build 2>/dev/null || true

  # 不卸载二进制（符合项目策略）
}
```

---

## nvim 模块精简

### 移除的代码

从 `_nvim::install_deps()` 中删除 rg/fd 安装：

```bash
# 以下由 cli-tools 模块安装，从此处删除：
case "${DOTFILES_OS}" in
mac)   core::pkg_install ripgrep fd ...      ;;
linux) core::pkg_install ripgrep fd-find ... ;;
esac
```

改为只保留 nvim 专属依赖：

```bash
case "${DOTFILES_OS}" in
mac)   core::run_cmd "Installing nvim dependencies" core::pkg_install node shfmt shellcheck ;;
linux) core::run_cmd "Installing nvim dependencies" core::pkg_install nodejs npm shfmt shellcheck ;;
esac
# tree-sitter-cli：nvim 专属（treesitter parser 编译器）
core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli
```

lazygit 暂时留在 nvim（待 git 模块重构时再迁移）。

---

## 后续关联任务：fzf 配置增强

本次不实现，但需在此记录：cli-tools 安装 bat/fd 后，fzf 模块应配置环境变量
以启用 preview 和 fd 集成。当前 fzf.sh 只有一行 `eval "$(fzf --zsh)"`。

待实现内容（单独任务）：

```bash
# FZF_DEFAULT_COMMAND — 用 fd 替代默认 find（尊重 .gitignore，快）
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# Ctrl+T 文件选择 — bat 语法高亮预览
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :300 {}'"

# Alt+C 目录跳转 — eza 树状预览
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"

# 通用样式 — catppuccin mocha 配色 + 布局
export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border --info=inline
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8'
```

实现方式：扩展现有 `modules/fzf.sh` 的 `core::ensure_block`，将上述 export
语句写在 `eval "$(fzf --zsh)"` 之前。依赖 cli-tools 模块提供 bat 和 fd。

### 新增断言（Phase 2）

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

### 卸载断言（Phase 4）

```bash
assert_file_missing "${HOME}/.config/bat/config"
```

### 原有断言

rg 的 assert_command 已经通过 nvim 间接覆盖，现在显式放在 cli-tools 断言中。
原 nvim 部分的 rg 测试可保留（冗余但不冲突）。

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| cargo install 编译耗时（5 个 crate 约 3-5 分钟） | CI 加 cargo cache（后续独立任务） |
| bat catppuccin 主题下载失败（网络问题） | 回退到内置主题 OneHalfDark |
| tealdeer --update 网络失败 | 非致命，log WARN 继续 |
| nvim 模块 --only 不含 cli-tools 时缺 rg/fd | nvim 已有 LazyVim 优雅降级（无 rg 则用 grep） |
