# Python 模块实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 新增 `modules/python.sh` 模块，确保 python3/pip/venv/pipx 可用，`~/.local/bin` 加入 PATH。

**架构：** 标准模块接口（install/uninstall）。使用 `core::pkg_install` 安装包，`core::ensure_block` 写 PATH。

**技术栈：** Bash, core::pkg_install, core::ensure_block

**提交策略：** design.md + tasks.md 一个 commit；代码改动另一个 commit。

---

### 任务 1: 创建 modules/python.sh

**文件：**
- 创建: `modules/python.sh`

- [ ] **步骤 1: 创建模块文件**

```bash
#!/usr/bin/env bash
# modules/python.sh — Python 3, pip, venv, pipx
# Platform: all
#
# Ensures python3/pip/venv are available, installs pipx for isolated CLI tool
# management, and adds ~/.local/bin to PATH.
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="python"
MODULE_DESC="Python 3, pip, venv, pipx"
MODULE_PLATFORM="all"
MODULE_DEPS=()

# Install python3, pip, venv, and pipx via system package manager.
_python::install_packages() {
  case "${DOTFILES_PKG_MANAGER}" in
  brew)
    core::run_cmd "Installing Python packages" core::pkg_install python3 pipx || return 1
    ;;
  apt)
    core::run_cmd "Installing Python packages" core::pkg_install python3 python3-pip python3-venv python-is-python3 pipx || return 1
    ;;
  dnf)
    core::run_cmd "Installing Python packages" core::pkg_install python3 python3-pip pipx || return 1
    ;;
  esac

  core::summary "    ✓ python3, pip, venv, pipx installed"
}

# Add ~/.local/bin to PATH (pip --user and pipx binaries).
_python::configure_path() {
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zprofile" "python" \
    '# Python: ~/.local/bin (pip --user and pipx binaries)
export PATH="${HOME}/.local/bin:${PATH}"'
  core::summary "    ✓ config → ~/.zprofile (PATH += ~/.local/bin)"
}

install() {
  _python::install_packages || return 1
  _python::configure_path || return 1
}

uninstall() {
  core::remove_block "${HOME}/.zprofile" "python"
  core::log INFO "Removed python PATH block from ~/.zprofile"
  core::summary "    ✓ removed PATH block from ~/.zprofile"
}
```

---

### 任务 2: 将 python 添加到模块列表

**文件：**
- 修改: `lib/modules.sh`

- [ ] **步骤 1: 在 cli-tools 之后、fzf 之前插入 python**

在 `cli-tools` 行之后添加：
```bash
  python           # after cli-tools: no hard deps; before fzf: logical grouping
```

最终顺序片段：
```
  cli-tools        # after rust/golang: cargo tools; before fzf: fzf preview uses bat/fd
  python           # after cli-tools: no hard deps; before fzf: logical grouping
  fzf              # before zoxide: zi interactive mode uses fzf
```

---

### 任务 3: 添加测试断言

**文件：**
- 修改: `tests/test_install.sh`

- [ ] **步骤 1: 在 Phase 2（安装验证）中添加 python 断言**

在 cli-tools 断言之后添加：

```bash
# python module
assert_command python3
assert_command pip3
assert_command pipx
assert_file_contains "${HOME}/.zprofile" "BEGIN dotfiles:python"
```

- [ ] **步骤 2: 在 Phase 1b（幂等性检查）的 .zprofile block 列表中添加 python**

在 `for block_id in rust golang homebrew; do` 行改为：

```bash
for block_id in rust golang homebrew python; do
```

- [ ] **步骤 3: 在 Phase 4（卸载验证）中添加 python 断言**

在 .zprofile block 卸载断言中添加：

```bash
assert_file_not_contains "${HOME}/.zprofile" "BEGIN dotfiles:python"
```

---

### 任务 4: 更新 README.md 模块表格

**文件：**
- 修改: `README.md`

- [ ] **步骤 1: 在模块表格 cli-tools 行之后添加 python**

```markdown
| `python` | all | Python 3, pip, venv, pipx, ~/.local/bin PATH |
```

---

### 任务 5: 创建模块文档

**文件：**
- 创建: `docs/modules/python.md`

- [ ] **步骤 1: 创建文档文件**

```markdown
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

    export PATH="${HOME}/.local/bin:${PATH}"

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
| `install` | install python3/pip/venv/pipx packages; write PATH block |
| `uninstall` | remove PATH block from ~/.zprofile; packages retained |

## Notes

- pipx creates isolated venvs in `~/.local/share/pipx/venvs/` and symlinks
  binaries to `~/.local/bin/`.
- No pip.conf is written — `[install] user = true` conflicts with venv usage.
- No pyenv — system python3 is sufficient for script/tool use.
```

---

### 任务 6: 提交

- [ ] **步骤 1: 提交设计文档**

```bash
git add docs/changes/2026-05-17-python-module/design.md
git commit -m "docs: add python module design"
```

- [ ] **步骤 2: 提交代码改动**

```bash
git add modules/python.sh lib/modules.sh tests/test_install.sh README.md docs/modules/python.md
git commit -m "feat: add python module (python3, pip, venv, pipx, PATH)"
```
