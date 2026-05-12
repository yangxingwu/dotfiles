# Dotfiles Project Gaps — TODO

Date: 2026-05-12

Identified gaps for the "full daily dev environment" goal. Each section is an
independent sub-project — implement in any order, one at a time.

---

## 1. Project Housekeeping

- [ ] Add LICENSE file (MIT, copyright yangxingwu)
- [ ] Expand .gitignore (*.swp, *.swo, *~, .env, .env.*)
- [ ] Fix README.md: `<your-username>` → `yangxingwu`

## 2. Modern CLI Tools Module

- [ ] Create `modules/cli-tools.sh` — install bat, eza, ripgrep, fd
- [ ] Add `cli-tools` to lib/modules.sh
- [ ] Write docs/modules/cli-tools.md
- [ ] Add test assertions (assert_command bat eza rg fd)

## 3. Zsh Configuration Module

- [ ] Create `modules/zsh-config.sh` — HISTSIZE, HISTFILE, SAVEHIST, setopt options
- [ ] Write settings via core::ensure_block into ~/.zshrc
- [ ] Add `zsh-config` to lib/modules.sh (after sheldon — needs shell to exist)
- [ ] Write docs/modules/zsh-config.md
- [ ] Add test assertions

## 4. Selective Module Install

- [ ] install.sh: parse `--skip module1,module2` argument
- [ ] uninstall.sh: same support
- [ ] Skip matched modules in the loop (log "skipped by --skip")
- [ ] Update README with usage example
- [ ] Test: run with --skip, verify skipped module has no side effects

## 5. Shell Aliases/Functions Module

- [ ] Create `modules/aliases.sh` — common aliases and utility functions
- [ ] Store function body in ~/.shell-aliases.sh, source via managed block
- [ ] Add `aliases` to lib/modules.sh
- [ ] Write docs/modules/aliases.md

## 6. Python Module

- [ ] Create `modules/python.sh` — pyenv install + global python version
- [ ] Handle platform differences (brew install pyenv vs apt/dnf)
- [ ] Configure pip (mirror source if needed)
- [ ] Add `python` to lib/modules.sh
- [ ] Write docs/modules/python.md
- [ ] Add test assertions (assert_command python3 pyenv)

## 7. Dry-run Mode

- [ ] install.sh: parse `--dry-run` flag
- [ ] Set global DOTFILES_DRY_RUN=1 when flag present
- [ ] core::pkg_install: print "[dry-run] would install: <pkg>" and return
- [ ] core::ensure_block: print "[dry-run] would write block '<id>' to <file>"
- [ ] Modules: ssh-keygen, gh auth, mkdir etc. check dry-run before executing
- [ ] Update README

## 8. Git Enhancement Tools Module

- [ ] Create `modules/git-tools.sh` — install delta, configure git pager
- [ ] git config --global core.pager delta
- [ ] git config --global interactive.diffFilter "delta --color-only"
- [ ] Add `git-tools` to lib/modules.sh (after git module)
- [ ] Write docs/modules/git-tools.md
- [ ] Add test assertions (assert_command delta)

## 9. ASCII Progress Bar

- [ ] Add `core::progress_bar <current> <total> <module_name>` to lib/core.sh
- [ ] Output format: `[=====>    ] 3/12 ssh`
- [ ] Call from core::run_module before running each module
- [ ] Use `\r` to overwrite in-place (only when stdout is a TTY)
- [ ] Print newline after each module completes (so log output stays readable)
- [ ] Works for both install.sh and uninstall.sh
