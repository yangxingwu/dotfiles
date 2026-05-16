# 模块依赖声明 + 状态查询实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 新增模块状态记录（installed-modules 文件）+ 依赖声明/检查机制（MODULE_DEPS）+ --status 查询参数。

**架构：** 状态函数和依赖检查逻辑集中在 lib/core.sh。core::run_module 在 install 成功后记录状态、install 前检查依赖。各模块按需声明 MODULE_DEPS。

**技术栈：** Bash、grep、纯文本状态文件。

**提交策略：** design.md + tasks.md 一个 commit；代码改动另一个 commit。

---

### 任务 1: 新增状态管理函数

**文件：**
- 修改: `lib/core.sh`

- [ ] **步骤 1: 在 core::backup 函数之后、"Argument parsing" 注释之前，添加状态管理函数**

```bash
# ── Module status tracking ───────────────────────────────────────────

_CORE_STATUS_FILE="${DOTFILES_CONFIG_DIR}/installed-modules"

# core::module_installed <name>
# Record that a module has been successfully installed.
# Adds or updates the module's entry in the status file with current timestamp.
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

# core::show_status — display installed modules from status file.
core::show_status() {
  if [[ ! -f "${_CORE_STATUS_FILE}" ]]; then
    printf 'No modules installed (status file not found).\n'
    return 0
  fi
  printf 'Installed modules:\n'
  local name timestamp
  while IFS=' ' read -r name timestamp; do
    printf '  %-20s %s\n' "${name}" "${timestamp}"
  done <"${_CORE_STATUS_FILE}"
}
```

---

### 任务 2: 修改 core::run_module 添加依赖检查和状态记录

**文件：**
- 修改: `lib/core.sh` (core::run_module 函数)

- [ ] **步骤 1: 在 platform check 之后、start_time 之前，添加依赖检查**

在当前的：

```bash
  if [[ "${MODULE_PLATFORM}" != "all" ]] &&
    [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    core::log INFO "Skipping ${name} (platform: ${MODULE_PLATFORM})"
    core::summary "  ${name}"
    core::summary "    — skipped (${MODULE_PLATFORM} only)"
    return 0
  fi

  local start_time end_time elapsed
  start_time="$(date +%s)"
```

之间插入：

```bash
  # Check module dependencies (if declared) — only for install action.
  # MODULE_DEPS is an optional array declared by modules that need other modules
  # to be installed first. Unset means "no dependencies".
  if [[ "${action}" == "install" ]] && [[ -n "${MODULE_DEPS+x}" ]]; then
    local -a missing=()
    local dep
    for dep in "${MODULE_DEPS[@]}"; do
      if ! core::module_is_installed "${dep}"; then
        missing+=("${dep}")
      fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
      local missing_list
      missing_list="$(printf '%s, ' "${missing[@]}")"
      missing_list="${missing_list%, }"
      core::log ERROR "${name} requires: ${MODULE_DEPS[*]} — not installed: ${missing_list}"
      core::summary "  ${name}"
      core::summary "    ✗ skipped (missing deps: ${missing_list})"
      return 0
    fi
  fi

  local start_time end_time elapsed
  start_time="$(date +%s)"
```

- [ ] **步骤 2: 在 install 成功后记录状态**

将当前的：

```bash
  if "${action}"; then
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    core::log INFO "✓ ${name} (${elapsed}s)"
    _CORE_MODULES_OK=$((_CORE_MODULES_OK + 1))
```

改为：

```bash
  if "${action}"; then
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    core::log INFO "✓ ${name} (${elapsed}s)"
    _CORE_MODULES_OK=$((_CORE_MODULES_OK + 1))
    # Record module status (install → mark done, uninstall → clear).
    if [[ "${action}" == "install" ]]; then
      core::module_installed "${name}"
    else
      core::module_uninstalled "${name}"
    fi
```

---

### 任务 3: 添加 --status 参数到 core::parse_args 和 core::usage

**文件：**
- 修改: `lib/core.sh` (core::parse_args 和 core::usage)

- [ ] **步骤 1: 在 core::usage 中添加 --status 说明**

将当前的：

```bash
  printf '  --list, -l         List available modules\n'
  printf '  --help, -h         Show this help\n'
```

改为：

```bash
  printf '  --status           Show installed modules and timestamps\n'
  printf '  --list, -l         List available modules\n'
  printf '  --help, -h         Show this help\n'
```

- [ ] **步骤 2: 在 core::parse_args 的 case 中添加 --status 分支**

在 `--list | -l)` 分支之后添加：

```bash
    --status)
      core::show_status
      exit 0
      ;;
```

---

### 任务 4: 添加 MODULE_DEPS 到各模块

**文件：**
- 修改: `modules/git.sh`
- 修改: `modules/cli-tools.sh`
- 修改: `modules/fzf.sh`
- 修改: `modules/sheldon.sh`
- 修改: `modules/atuin.sh`
- 修改: `modules/nvim.sh`

- [ ] **步骤 1: modules/git.sh — 在 MODULE_PLATFORM 行之后添加**

```bash
MODULE_DEPS=("ssh" "rust" "golang")
```

- [ ] **步骤 2: modules/cli-tools.sh — 在 MODULE_PLATFORM 行之后添加**

```bash
MODULE_DEPS=("rust")
```

- [ ] **步骤 3: modules/fzf.sh — 在 MODULE_PLATFORM 行之后添加**

```bash
MODULE_DEPS=("cli-tools")
```

- [ ] **步骤 4: modules/sheldon.sh — 在 MODULE_PLATFORM 行之后添加**

```bash
MODULE_DEPS=("rust")
```

- [ ] **步骤 5: modules/atuin.sh — 在 MODULE_PLATFORM 行之后添加**

```bash
MODULE_DEPS=("rust")
```

- [ ] **步骤 6: modules/nvim.sh — 在 MODULE_PLATFORM 行之后添加**

```bash
MODULE_DEPS=("rust" "golang" "git" "cli-tools")
```

---

### 任务 5: 在 core::run_module 中 unset MODULE_DEPS

**文件：**
- 修改: `lib/core.sh` (core::run_module 顶部)

- [ ] **步骤 1: 在 unset MODULE_NAME MODULE_DESC MODULE_PLATFORM 行中添加 MODULE_DEPS**

将当前的：

```bash
  unset MODULE_NAME MODULE_DESC MODULE_PLATFORM
```

改为：

```bash
  unset MODULE_NAME MODULE_DESC MODULE_PLATFORM MODULE_DEPS
```

这确保上一个模块的 MODULE_DEPS 不会泄漏到下一个模块。

---

### 任务 6: 更新测试

**文件：**
- 修改: `tests/test_install.sh`

- [ ] **步骤 1: 在 Phase 2 末尾（Shell init blocks 验证之前）添加状态文件断言**

在 `# Shell init blocks in ~/.zshrc` 行之前添加：

```bash
# Module status file
assert_file_exists "${HOME}/.config/dotfiles/installed-modules"
assert_file_contains "${HOME}/.config/dotfiles/installed-modules" "rust"
assert_file_contains "${HOME}/.config/dotfiles/installed-modules" "nvim"
assert_file_contains "${HOME}/.config/dotfiles/installed-modules" "cli-tools"
```

- [ ] **步骤 2: 在 Phase 4 末尾添加状态文件清除断言**

在 Phase 4 的最后（`# ─── Result` 之前）添加：

```bash
# Module status cleared after uninstall
assert_file_not_contains "${HOME}/.config/dotfiles/installed-modules" "nvim"
assert_file_not_contains "${HOME}/.config/dotfiles/installed-modules" "rust"
```

---

### 任务 7: 验证与提交

- [ ] **步骤 1: 运行 shellcheck**

运行: `shellcheck lib/core.sh modules/git.sh modules/cli-tools.sh modules/fzf.sh modules/sheldon.sh modules/atuin.sh modules/nvim.sh`
预期: 无错误。

- [ ] **步骤 2: 运行 shfmt**

运行: `shfmt -w lib/core.sh modules/git.sh modules/cli-tools.sh modules/fzf.sh modules/sheldon.sh modules/atuin.sh modules/nvim.sh`

- [ ] **步骤 3: 验证 --status**

运行: `./install.sh --status`
预期: 输出 "No modules installed (status file not found)." 或已有记录。

- [ ] **步骤 4: 验证 --list 仍正常**

运行: `./install.sh --list`
预期: 输出所有模块列表。

- [ ] **步骤 5: 提交 design.md + tasks.md**

```bash
git add docs/changes/2026-05-16-module-deps-status/design.md \
        docs/changes/2026-05-16-module-deps-status/tasks.md
git commit -m "docs: add module dependency + status query design and plan

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

- [ ] **步骤 6: 提交代码改动**

```bash
git add lib/core.sh modules/git.sh modules/cli-tools.sh modules/fzf.sh \
        modules/sheldon.sh modules/atuin.sh modules/nvim.sh \
        tests/test_install.sh
git commit -m "feat: add module dependency declaration and status tracking

New features:
- core::module_installed / core::module_is_installed / core::module_uninstalled
  for tracking install/uninstall state in ~/.config/dotfiles/installed-modules
- MODULE_DEPS optional array in module interface — declare dependencies on
  other modules; core::run_module checks before install, skips with clear
  error if deps not met
- --status flag shows installed modules with timestamps
- Dependency checking runs on every install (full or --only); full installs
  pass naturally as modules run in order; --only fails cleanly if deps missing

Modules with declared dependencies:
  git (ssh, rust, golang), cli-tools (rust), fzf (cli-tools),
  sheldon (rust), atuin (rust), nvim (rust, golang, git, cli-tools)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```
