# Node.js 模块实施计划

## 任务列表

### 1. 新增 `modules/nodejs.sh`

```bash
MODULE_NAME="nodejs"
MODULE_DESC="Node.js runtime via fnm (Fast Node Manager)"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust")
```

**install() 步骤**：

1. 检查 `command -v fnm`，不存在则 `cargo install fnm`
2. `fnm install --lts`
3. `fnm default lts-latest`
4. 通过 `core::ensure_block` 写入 shell init：
   ```bash
   eval "$(fnm env --use-on-cd)"
   ```

**uninstall() 步骤**：

1. 移除 shell init block
2. `rm -rf "${HOME}/.local/share/fnm"`（fnm 安装的 Node 版本）
3. 不删除 fnm 二进制（与其他模块保持一致：uninstall 只清理配置和数据，不删二进制）

### 2. 修改 `modules/nvim.sh`

1. `MODULE_DEPS` 添加 `"nodejs"`
2. 删除 `_nvim::install_deps` 中的平台 case：
   - macOS: 删除 `node`（从 `core::pkg_install node shfmt shellcheck`）
   - Linux: 删除 `nodejs npm`（从 `core::pkg_install nodejs npm shfmt shellcheck ...`）
3. 删除 Node.js provider 中的 `sudo npm install -g neovim` 分支
   — fnm 安装在用户空间，所有平台统一 `npm install -g neovim`（无需 sudo）

### 3. 修改 `lib/modules.sh` 模块列表

在 `DOTFILES_MODULES` 数组中添加 `nodejs`，位于 `rust` 之后、`nvim` 之前。

### 4. 修改测试

`tests/test_install.sh` 添加验证：
- `node --version` 可执行
- `npm --version` 可执行
- `fnm --version` 可执行

### 5. 无需修改 uninstall.sh

`uninstall.sh` 使用同一个 `lib/modules.sh` 列表，自动包含 nodejs 模块。

## 执行顺序

1. 先提交设计文档 + 实施计划
2. 再提交代码实现（一个 commit），包括：
   - `modules/nodejs.sh`
   - `lib/modules.sh` 模块列表
   - `modules/nvim.sh` 修改
   - `docs/modules/nodejs.md` 模块文档
   - `README.md` 模块表格
   - `tests/test_install.sh` 测试
