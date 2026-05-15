# fzf 模块配置增强设计

日期: 2026-05-15

## 概述

增强现有 `modules/fzf.sh`，将 fzf 从"只装了二进制 + 一行 eval"升级为
完整配置：fd 搜索源、bat 文件预览、eza 目录预览、catppuccin mocha 配色、
合理的布局默认值。使 Ctrl+T / Ctrl+R / Alt+C 开箱即用。

## 动机

当前 fzf.sh 只有 `pkg_install fzf` + `eval "$(fzf --zsh)"`。用户得到的是：
- Ctrl+T 用系统 `find` 搜索（慢，不尊重 .gitignore，显示 .git/ 垃圾）
- 无文件预览（选文件全靠猜）
- 无目录预览（Alt+C 跳目录靠文件名判断）
- 默认配色（跟 starship/ghostty/bat 的 catppuccin 主题不一致）

cli-tools 模块已安装 bat/fd/eza，但 fzf 没有配置使用它们。

## 变更范围

| 文件 | 动作 | 说明 |
|------|------|------|
| `modules/fzf.sh` | 扩展 | clone catppuccin/fzf + 配置环境变量 |
| `tests/test_install.sh` | 更新 | 新增断言 |
| `docs/modules/fzf.md` | 更新 | 文档同步 |

不需要调整模块顺序（fzf 已在 cli-tools 之后）。

---

## 详细设计

### 内部结构

```bash
_fzf::clone_theme()   # clone/pull catppuccin/fzf → ~/.local/share/fzf/catppuccin
_fzf::write_config()  # 写 .zshrc managed block（source 主题 + 环境变量 + eval）

install() {
  core::pkg_install fzf
  _fzf::clone_theme
  _fzf::write_config
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "fzf"
  rm -rf "${HOME}/.local/share/fzf/catppuccin"
}
```

### catppuccin 主题管理

与 lazygit 模块相同模式：

- `git clone https://github.com/catppuccin/fzf.git ~/.local/share/fzf/catppuccin`
- 已有则 `git -C pull` 更新
- .zshrc 中 `source` 主题文件，不硬编码颜色值
- 更新主题：`cd ~/.local/share/fzf/catppuccin && git pull`

### .zshrc managed block 内容

写入 `~/.zshrc` 的 `fzf` managed block：

```bash
# FZF configuration
# See: https://github.com/junegunn/fzf#environment-variables

# Catppuccin Mocha theme
# Source: https://github.com/catppuccin/fzf/blob/main/themes/catppuccin-fzf-mocha.sh
[[ -f "${HOME}/.local/share/fzf/catppuccin/themes/catppuccin-fzf-mocha.sh" ]] && \
  source "${HOME}/.local/share/fzf/catppuccin/themes/catppuccin-fzf-mocha.sh"

# Layout and behavior defaults
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} --height=60% --layout=reverse --border --info=inline"

# Use fd as default source (respects .gitignore, fast, hidden files included)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# Ctrl+T: file picker with bat preview
export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :300 {}' --select-1 --exit-0"

# Ctrl+R: disabled — atuin handles history search (runs after fzf in module order)
export FZF_CTRL_R_COMMAND=""

# Alt+C: directory jump with eza tree preview
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"

# Activate fzf key bindings and completion for zsh
eval "$(fzf --zsh)"
```

### 设计决策

1. **`source` 主题文件而非硬编码颜色值** — 上游更新时 git pull 即可同步，
   不需要手动修改模块代码。

2. **`--preview` 只在 CTRL_T_OPTS 和 ALT_C_OPTS** — 遵循 fzf 官方警告：
   不要把 --preview 放在 FZF_DEFAULT_OPTS 里，因为非文件输入（如
   `ps -ef | fzf`）会导致 preview 命令报错。

3. **禁用 fzf 的 Ctrl+R** — 设置 `FZF_CTRL_R_COMMAND=""`。atuin 模块（在
   fzf 之后运行）会接管 Ctrl+R 作为历史搜索。fzf 的 Ctrl+R 与 atuin 冲突
   且 atuin 的历史搜索功能更强（SQLite 存储、上下文感知）。fzf 仍负责
   Ctrl+T（文件选择）和 Alt+C（目录跳转）。

4. **追加布局到 FZF_DEFAULT_OPTS** — 用 `${FZF_DEFAULT_OPTS}` 保留 source
   设置的颜色，再追加 `--height --layout --border --info`。

5. **`--select-1 --exit-0`** — CTRL_T 只有单个结果时自动选中，无结果时
   自动退出（fzf 官方推荐）。

6. **eval 放最后** — fzf --zsh 生成的 key bindings 会读取上面定义的
   环境变量（包括 FZF_CTRL_R_COMMAND="" 来跳过 Ctrl+R 绑定）。

### 幂等性

- `core::ensure_block` 每次覆写整个 block，天然幂等
- git clone 有 `-d` 守卫（已有则 pull）
- `core::pkg_install fzf` 内部已幂等

### uninstall()

```bash
uninstall() {
  core::remove_block "${HOME}/.zshrc" "fzf"
  core::summary "    ✓ removed fzf block from ~/.zshrc"

  rm -rf "${HOME}/.local/share/fzf/catppuccin"
  core::summary "    ✓ removed catppuccin theme clone"
}
```

---

## 测试断言

### Phase 2（安装验证）

```bash
# fzf
assert_command fzf
assert_dir_exists "${HOME}/.local/share/fzf/catppuccin"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:fzf"
assert_file_contains "${HOME}/.zshrc" "FZF_DEFAULT_COMMAND"
assert_file_contains "${HOME}/.zshrc" "catppuccin-fzf-mocha"
```

### Phase 4（卸载验证）

```bash
# fzf uninstall
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:fzf"
assert_dir_missing "${HOME}/.local/share/fzf/catppuccin"
```

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| catppuccin/fzf clone 网络失败 | source 行会报错；考虑加 `[[ -f ... ]] && source` 守卫 |
| fd/bat/eza 不在 PATH（用户 --skip cli-tools） | fzf 自身仍能工作，preview 报错但不影响选择功能 |
| FZF_DEFAULT_OPTS 追加导致变量过长 | 实测单行 ~200 字符，无问题 |
