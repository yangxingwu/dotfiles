# 模块依赖声明 + 状态查询设计

日期: 2026-05-16

## 概述

新增两个关联功能：
1. **Module Status** — 记录模块安装/卸载状态到文件，支持 `--status` 查询
2. **Module Dependency Declaration** — 模块声明依赖，install 前检查依赖是否满足

两者共享状态文件 `~/.config/dotfiles/installed-modules`。

## 动机

- `--only nvim` 崩溃报 "cargo not found"——用户不知道需要先装 rust
- 无法查看"当前装了什么模块"——重跑 install.sh 时不知道什么状态
- 依赖关系只在 lib/modules.sh 注释里，运行时不检查

## 变更范围

| 文件 | 动作 | 说明 |
|------|------|------|
| `lib/core.sh` | 新增 | core::module_installed, core::module_is_installed, core::module_uninstalled |
| `lib/core.sh` (core::run_module) | 修改 | install 前检查 deps，成功后记录状态 |
| `lib/core.sh` (core::parse_args) | 修改 | 新增 --status 参数 |
| `modules/*.sh` | 修改 | 需要依赖的模块加 MODULE_DEPS |
| `uninstall.sh` (core::run_module) | 修改 | uninstall 成功后清除状态 |
| `tests/test_install.sh` | 更新 | 验证状态文件、--status |

---

## 设计

### 状态文件

路径：`~/.config/dotfiles/installed-modules`（在 `${DOTFILES_CONFIG_DIR}` 下）

格式：纯文本，每行 `<模块名> <ISO时间戳>`：

```
ssh 2026-05-16T14:30:22
rust 2026-05-16T14:30:45
golang 2026-05-16T14:31:03
git 2026-05-16T14:31:50
cli-tools 2026-05-16T14:33:15
fzf 2026-05-16T14:33:20
zoxide 2026-05-16T14:33:21
sheldon 2026-05-16T14:34:00
atuin 2026-05-16T14:35:10
starship 2026-05-16T14:35:12
ghostty 2026-05-16T14:35:15
nvim 2026-05-16T14:37:00
tmux 2026-05-16T14:37:05
```

### 新增函数（lib/core.sh）

```bash
_CORE_STATUS_FILE="${DOTFILES_CONFIG_DIR}/installed-modules"

# core::module_installed <name>
# Record that a module has been successfully installed.
# Adds or updates the module's entry in the status file.
core::module_installed() {
  local name="${1}"
  local timestamp
  timestamp="$(date +%Y-%m-%dT%H:%M:%S)"

  mkdir -p "$(dirname "${_CORE_STATUS_FILE}")"

  # Remove existing entry (if re-installing), then append new one.
  if [[ -f "${_CORE_STATUS_FILE}" ]]; then
    grep -v "^${name} " "${_CORE_STATUS_FILE}" >"${_CORE_STATUS_FILE}.tmp" || true
    mv "${_CORE_STATUS_FILE}.tmp" "${_CORE_STATUS_FILE}"
  fi
  printf '%s %s\n' "${name}" "${timestamp}" >>"${_CORE_STATUS_FILE}"
}

# core::module_is_installed <name>
# Check whether a module has been previously installed (exists in status file).
# Returns 0 if installed, 1 if not.
core::module_is_installed() {
  local name="${1}"
  [[ -f "${_CORE_STATUS_FILE}" ]] && grep -q "^${name} " "${_CORE_STATUS_FILE}"
}

# core::module_uninstalled <name>
# Remove a module's entry from the status file (called after successful uninstall).
core::module_uninstalled() {
  local name="${1}"
  [[ -f "${_CORE_STATUS_FILE}" ]] || return 0
  grep -v "^${name} " "${_CORE_STATUS_FILE}" >"${_CORE_STATUS_FILE}.tmp" || true
  mv "${_CORE_STATUS_FILE}.tmp" "${_CORE_STATUS_FILE}"
}
```

### core::run_module 变更

**install 路径：**

```bash
# After sourcing module and platform check, before calling install():

# Check module dependencies (if declared).
if [[ -n "${MODULE_DEPS+x}" ]]; then
  local -a missing=()
  local dep
  for dep in "${MODULE_DEPS[@]}"; do
    if ! core::module_is_installed "${dep}"; then
      missing+=("${dep}")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    core::log ERROR "${name} requires: ${MODULE_DEPS[*]} — not installed: ${missing[*]}"
    core::summary "    ✗ skipped (missing deps: ${missing[*]})"
    return 0  # skip, don't crash
  fi
fi

# ... execute install ...

# After successful install:
core::module_installed "${name}"
```

**uninstall 路径：**

```bash
# After successful uninstall:
core::module_uninstalled "${name}"
```

### MODULE_DEPS 声明

可选字段。不声明 = 无依赖（向后兼容）。

需要声明的模块：

| 模块 | MODULE_DEPS |
|------|-------------|
| git | `("ssh" "rust" "golang")` |
| cli-tools | `("rust")` |
| fzf | `("cli-tools")` |
| sheldon | `("rust")` |
| atuin | `("rust")` |
| nvim | `("rust" "golang" "git" "cli-tools")` |

不需要声明的模块（无外部依赖或只依赖 bootstrap）：
homebrew, font-hack-nerd-font, ssh, rust, golang, zoxide, starship, ghostty, tmux

### --status 参数

在 `core::parse_args` 中新增 `--status`：

```bash
--status)
  core::show_status
  exit 0
  ;;
```

```bash
# core::show_status — display installed modules from status file.
core::show_status() {
  if [[ ! -f "${_CORE_STATUS_FILE}" ]]; then
    printf 'No modules installed (status file not found).\n'
    return 0
  fi
  printf 'Installed modules:\n'
  while IFS=' ' read -r name timestamp; do
    printf '  %-20s %s\n' "${name}" "${timestamp}"
  done <"${_CORE_STATUS_FILE}"
}
```

输出示例：

```
Installed modules:
  ssh                  2026-05-16T14:30:22
  rust                 2026-05-16T14:30:45
  golang               2026-05-16T14:31:03
  git                  2026-05-16T14:31:50
  cli-tools            2026-05-16T14:33:15
  ...
```

### 依赖检查时机

**永远检查**（不区分 --only 还是全量）：
- 全量安装时，模块按顺序执行，前面的成功后 mark installed → 后面检查自然通过
- `--only` 时，如果前置模块没装过 → 检查失败 → 报错跳过

逻辑统一，无需特殊分支。

### 幂等性

- 重复安装：`core::module_installed` 更新时间戳（先删旧行再写新行）
- 状态文件不存在时：`core::module_is_installed` 返回 false，`core::module_uninstalled` no-op
- MODULE_DEPS 未声明时：跳过依赖检查（`-n "${MODULE_DEPS+x}"` 检查变量是否 set）

### .zshrc block 间无顺序依赖

经验证，当前所有 .zshrc/.zprofile blocks 互相独立（每个都是自包含的
eval/source/alias/export）。`--only` 安装任何单个模块写入的 block 不会因
其他 block 缺失而出错。依赖检查只需关注二进制/模块级依赖，不需要管 block 顺序。

---

## 测试

### Phase 2 新增

```bash
# Module status file
assert_file_exists "${HOME}/.config/dotfiles/installed-modules"
assert_file_contains "${HOME}/.config/dotfiles/installed-modules" "rust"
assert_file_contains "${HOME}/.config/dotfiles/installed-modules" "nvim"
```

### Phase 4 新增

```bash
# Status file cleared after uninstall
assert_file_not_contains "${HOME}/.config/dotfiles/installed-modules" "nvim"
```

### --status 测试

```bash
# Verify --status output
output="$(./install.sh --status)"
assert "status shows rust" echo "${output}" | grep -q "rust"
```

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 旧安装没有状态文件（已装过但没记录） | 全量重跑 install.sh 一次即可补全状态 |
| 状态文件被手动删除 | 依赖检查失败 → 报错但不崩；重跑 install.sh 恢复 |
| MODULE_DEPS 声明错误（漏写/多写） | 跟注释一样靠 review，但至少运行时有检查了 |
