# Python 模块设计

日期: 2026-05-17

## 概述

新增 `modules/python.sh` 模块，确保 python3、pip、venv 可用，安装 pipx
用于全局 CLI 工具隔离安装，并将 `~/.local/bin` 加入 PATH。

## 动机

Python 是日常工具——脚本、自动化、CLI 工具。当前状态：

- macOS：系统 python3 存在但无 pip（需 `python3 -m ensurepip` 或 brew）
- Linux：可能缺少 python3-pip 和 python3-venv 包
- `~/.local/bin` 不在 PATH（pip --user 和 pipx 安装的二进制找不到）
- 全局 CLI 工具（httpie、ruff 等）无隔离安装方式

## 设计决策

### 为什么装 pipx

`pip install --user` 的问题：多个 CLI 工具共享 `~/.local/lib/python3.x/site-packages/`，
依赖互相覆盖会导致工具 break。pipx 为每个工具创建独立 venv，彻底隔离。

pipx 是 PyPA（Python Packaging Authority）官方推荐的全局 CLI 工具安装方式。
参考：https://packaging.python.org/en/latest/guides/installing-stand-alone-command-line-tools/

### 为什么不写 pip.conf

最初考虑 `pip.conf [install] user = true` 来省去每次 `--user`。但该配置在
venv 内生效时会报错：

```
ERROR: Can not perform a '--user' install.
User site-packages are not visible in this virtualenv.
```

用户也在 venv 中写 Python 代码，所以不能写该配置。有 pipx 后也无需 `--user`。

### 为什么不装 pyenv

用户不做 Python 多版本开发，系统 python3 够用。YAGNI。

---

## 模块接口

```bash
MODULE_NAME="python"
MODULE_DESC="Python 3, pip, venv, pipx"
MODULE_PLATFORM="all"
MODULE_DEPS=()
```

## install() 逻辑

### 1. 安装基础包

| 平台 | 包名 | 说明 |
|------|------|------|
| macOS (brew) | `python3` | brew python3 自带 pip 和 venv，`python` 已 symlink 到 python3 |
| Ubuntu (apt) | `python3 python3-pip python3-venv python-is-python3` | apt 需要分别安装；python-is-python3 确保 `python` 命令可用 |
| Fedora (dnf) | `python3 python3-pip` | Fedora python3 自带 venv，`python` 已 symlink 到 python3 |

### 2. 安装 pipx

| 平台 | 方式 |
|------|------|
| macOS (brew) | `core::pkg_install pipx` |
| Ubuntu (apt) | `core::pkg_install pipx` |
| Fedora (dnf) | `core::pkg_install pipx` |

pipx 工作方式：为每个 CLI 工具创建独立 venv（存于 `~/.local/share/pipx/venvs/`），
二进制 symlink 到 `~/.local/bin/`。因此 pipx 和 pip --user 共享同一个 bin 路径，
一个 PATH block 即可覆盖。

### 3. PATH block

通过 `core::ensure_block` 写入 `~/.zprofile`（block ID: `python`）：

```bash
# Python: ~/.local/bin (pip --user and pipx binaries)
export PATH="${HOME}/.local/bin:${PATH}"
```

写 `.zprofile` 而非 `.zshrc`——与 rust、golang 模块一致（PATH 是环境变量，
login shell 设一次即可）。

## uninstall() 逻辑

- `core::remove_block "${HOME}/.zprofile" "python"`
- 不卸载 python3/pipx 包（系统依赖太多）
- 不删 `~/.local/bin` 目录（可能有其他内容）

## 幂等性

- `core::pkg_install`：内部已幂等（已安装则跳过）
- `core::ensure_block`：已存在则替换（声明式）

## 模块顺序

```
... → golang → git → cli-tools → python → fzf → ...
```

无硬依赖。放在 cli-tools 之后（逻辑分组：语言/工具类模块一起）。

## 内部结构

```bash
_python::install_packages()   # python3, pip, venv, pipx
_python::configure_path()     # core::ensure_block ~/.zprofile

install() {
  _python::install_packages || return 1
  _python::configure_path || return 1
}

uninstall() {
  core::remove_block "${HOME}/.zprofile" "python"
}
```

## 测试断言

### Phase 2（安装后）

```bash
assert_command python3
assert_command pip3
assert_command pipx
assert_file_contains "${HOME}/.zprofile" "BEGIN dotfiles:python"
```

### Phase 4（卸载后）

```bash
assert_file_not_contains "${HOME}/.zprofile" "BEGIN dotfiles:python"
```

## 变更文件清单

| 文件 | 动作 | 说明 |
|------|------|------|
| `modules/python.sh` | 新建 | 模块实现 |
| `lib/modules.sh` | 修改 | 添加 python 到模块列表 |
| `tests/test_install.sh` | 修改 | 添加测试断言 |
| `README.md` | 修改 | 模块表格添加 python |
| `docs/modules/python.md` | 新建 | 模块文档 |

## 风险

| 风险 | 缓解 |
|------|------|
| Ubuntu 旧版无 pipx 包 | Ubuntu 22.04+ 有 pipx；更旧版本 `pip install --user pipx` 回退 |
| brew python3 自动升级可能破坏 venv | 非本模块问题，brew 通用行为 |
