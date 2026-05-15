# fzf 模块配置增强实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 增强 `modules/fzf.sh`，集成 fd 搜索源、bat 文件预览、eza 目录预览、catppuccin mocha 配色，使 fzf 开箱即用。

**架构：** 扩展现有 fzf.sh，新增 clone catppuccin 主题仓库 + 扩展 .zshrc managed block 内容（环境变量配置）。

**技术栈：** Bash（模块接口）、core::ensure_block、git clone。

**提交策略：** design.md + tasks.md 一个 commit；代码改动另一个 commit。

---

### 任务 1: 重写 modules/fzf.sh

**文件：**
- 修改: `modules/fzf.sh`（完全重写）

- [ ] **步骤 1: 编写完整模块文件**

```bash
#!/usr/bin/env bash
# modules/fzf.sh — fzf fuzzy finder with fd/bat/eza integration
# Platform: all
#
# Configures:
#   - fzf binary installation
#   - Catppuccin Mocha theme (cloned from https://github.com/catppuccin/fzf)
#   - fd as default search source (respects .gitignore)
#   - bat as file preview for Ctrl+T
#   - eza as directory preview for Alt+C
#   - Layout defaults (height, reverse, border)
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="fzf"
MODULE_DESC="fzf fuzzy finder with fd/bat/eza integration"
MODULE_PLATFORM="all"

_FZF_THEME_REPO="https://github.com/catppuccin/fzf.git"
_FZF_THEME_DIR="${HOME}/.local/share/fzf/catppuccin"

# Clone or update catppuccin/fzf theme repository.
_fzf::clone_theme() {
  if [[ -d "${_FZF_THEME_DIR}" ]]; then
    core::run_cmd "Updating fzf catppuccin theme" git -C "${_FZF_THEME_DIR}" pull --quiet
  else
    mkdir -p "$(dirname "${_FZF_THEME_DIR}")"
    core::run_cmd "Cloning fzf catppuccin theme" git clone --quiet "${_FZF_THEME_REPO}" "${_FZF_THEME_DIR}"
  fi
  core::summary "    ✓ catppuccin theme → ~/.local/share/fzf/catppuccin"
}

# Write fzf configuration block to .zshrc.
_fzf::write_config() {
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "fzf" \
    '# FZF configuration
# See: https://github.com/junegunn/fzf#environment-variables

# Catppuccin Mocha theme
# Source: https://github.com/catppuccin/fzf/blob/main/themes/catppuccin-fzf-mocha.sh
[[ -f "${HOME}/.local/share/fzf/catppuccin/themes/catppuccin-fzf-mocha.sh" ]] && \
  source "${HOME}/.local/share/fzf/catppuccin/themes/catppuccin-fzf-mocha.sh"

# Layout and behavior defaults
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} --height=60% --layout=reverse --border --info=inline"

# Use fd as default source (respects .gitignore, fast, hidden files included)
export FZF_DEFAULT_COMMAND='\''fd --type f --hidden --follow --exclude .git'\''

# Ctrl+T: file picker with bat preview
export FZF_CTRL_T_COMMAND='\''fd --type f --hidden --follow --exclude .git'\''
export FZF_CTRL_T_OPTS="--preview '\''bat --color=always --style=numbers --line-range :300 {}'\'' --select-1 --exit-0"

# Ctrl+R: disabled — atuin handles history search (runs after fzf in module order)
export FZF_CTRL_R_COMMAND=""

# Alt+C: directory jump with eza tree preview
export FZF_ALT_C_COMMAND='\''fd --type d --hidden --follow --exclude .git'\''
export FZF_ALT_C_OPTS="--preview '\''eza --tree --level=2 --color=always {}'\'' "

# Activate fzf key bindings and completion for zsh
eval "$(fzf --zsh)"'
  core::summary "    ✓ config → ~/.zshrc (fzf with fd/bat/eza/catppuccin)"
}

install() {
  core::run_cmd "Installing fzf" core::pkg_install fzf
  _fzf::clone_theme
  _fzf::write_config
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "fzf"
  core::summary "    ✓ removed fzf block from ~/.zshrc"

  rm -rf "${_FZF_THEME_DIR}"
  core::summary "    ✓ removed catppuccin theme clone"
}
```

---

### 任务 2: 更新集成测试

**文件：**
- 修改: `tests/test_install.sh`

- [ ] **步骤 1: 更新 Phase 2 中的 fzf 断言**

将现有的 `assert_command fzf` 行（约第 83 行）替换为：

```bash
assert_command fzf
assert_dir_exists "${HOME}/.local/share/fzf/catppuccin"
assert_file_contains "${HOME}/.zshrc" "FZF_DEFAULT_COMMAND"
assert_file_contains "${HOME}/.zshrc" "catppuccin-fzf-mocha"
```

- [ ] **步骤 2: 更新 Phase 4 中的 fzf 卸载断言**

将现有的 `assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:fzf"` 替换为：

```bash
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:fzf"
assert_dir_missing "${HOME}/.local/share/fzf/catppuccin"
```

---

### 任务 3: 更新文档

**文件：**
- 修改: `docs/modules/fzf.md`

- [ ] **步骤 1: 重写 docs/modules/fzf.md**

```markdown
# Module: fzf

[fzf](https://github.com/junegunn/fzf) fuzzy finder with fd/bat/eza integration
and catppuccin mocha theme.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install fzf`; clone catppuccin/fzf theme; write managed `fzf` block to `~/.zshrc` with fd source, bat/eza preview, catppuccin colors, layout defaults |
| `uninstall` | remove the `fzf` block from `~/.zshrc`; remove catppuccin theme clone (package is preserved) |

## Configuration

The managed block in `~/.zshrc` configures:

| Variable | Value | Purpose |
|---|---|---|
| `FZF_DEFAULT_COMMAND` | `fd --type f --hidden --follow --exclude .git` | Fast file search respecting .gitignore |
| `FZF_CTRL_T_COMMAND` | same as above | File picker source |
| `FZF_CTRL_T_OPTS` | bat preview + --select-1 --exit-0 | Syntax-highlighted file preview |
| `FZF_ALT_C_COMMAND` | `fd --type d --hidden --follow --exclude .git` | Directory search |
| `FZF_ALT_C_OPTS` | eza tree preview | Directory tree preview |
| `FZF_DEFAULT_OPTS` | catppuccin colors + height/reverse/border/info | Theme + layout |

## Key bindings

- **Ctrl+R**: fuzzy search command history
- **Ctrl+T**: fuzzy file picker (with bat syntax-highlighted preview)
- **Alt+C**: fuzzy directory jump (with eza tree preview)

## Dependencies

- `cli-tools` module provides fd, bat, eza (must run before fzf)
- Catppuccin theme cloned to `~/.local/share/fzf/catppuccin/`
- Update theme: `cd ~/.local/share/fzf/catppuccin && git pull`

## Notes

- The fzf package must be installed before the sheldon module runs because
  sheldon's `fzf-tab` plugin requires the `fzf` binary on PATH.
- `--preview` is NOT in FZF_DEFAULT_OPTS (fzf official recommendation: preview
  commands fail with non-file inputs like `ps -ef | fzf`).
- If catppuccin theme file is missing, fzf works normally with default colors.
```

---

### 任务 4: 验证与提交

- [ ] **步骤 1: 运行 shellcheck**

运行: `shellcheck modules/fzf.sh`
预期: 无错误。

- [ ] **步骤 2: 运行 shfmt**

运行: `shfmt -w modules/fzf.sh`

- [ ] **步骤 3: 提交 design.md + tasks.md**

```bash
git add docs/changes/2026-05-15-fzf-enhancement/design.md \
        docs/changes/2026-05-15-fzf-enhancement/tasks.md
git commit -m "docs: add fzf enhancement design and implementation plan

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

- [ ] **步骤 4: 提交代码改动**

```bash
git add modules/fzf.sh tests/test_install.sh docs/modules/fzf.md
git commit -m "feat(fzf): add fd/bat/eza integration and catppuccin theme

Enhance fzf module from bare eval to full configuration:
- Clone catppuccin/fzf theme repo for auto-updatable colors
- fd as default search source (respects .gitignore, fast)
- bat syntax-highlighted preview for Ctrl+T file picker
- eza tree preview for Alt+C directory jump
- Layout defaults: --height=60% --layout=reverse --border --info=inline
- Graceful degradation: theme source guarded by [[ -f ]]

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```
