# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Zsh dotfiles for macOS and Ubuntu. Sourced via `source $HOME/dev/dotfiles/zshrc/init.zsh` in `~/.zshrc`.

## Structure

- `zshrc/platform.zsh` — platform abstractions: detection (`__is_macos`/`__is_linux`), clipboard (`clipcopy`/`clippaste`), notification (`__notify`), wake-lock (`__keep_awake`), key injection (`__press_enter`), path resolution (`__first_file`), config symlinks (`__link_config`). Also sourced by `scripts/whisper/record.sh` under bash — keep bash-parseable
- `zshrc/pick.zsh` — `__fzf` + `__pick`, the one selection seam every domain module uses
- `zshrc/init.zsh` — entrypoint; sources platform.zsh first, sets up completions, sources all other zshrc files, defines general aliases, loads zsh plugins
- `zshrc/bootstrap.zsh` — machine bootstrap (`zinit`) and agent setup (`ainit`)
- `zshrc/git.zsh` — git aliases and fzf-powered branch/stash/worktree helpers
- `zshrc/tmux.zsh` — tmux aliases (`tm` prefix) and keybindings
- `zshrc/agent-worktree.zsh` — shared Claude/Codex worktree + tmux workflow (`cgt`/`cogt`/`agtd`)
- `zshrc/tailscale.zsh` — Tailscale aliases (`ts` prefix), fzf device pickers, and `tsinit` for auth
- `zshrc/claude.zsh` — Claude Code aliases and `cinit`
- `zshrc/codex.zsh` — Codex CLI aliases (`co` prefix)
- `zshrc/vim.zsh` — vim config (sets `VIMINIT` to point at repo)
- `zshrc/docker.zsh` — Docker aliases (`d` prefix), compose (`dc` prefix), fzf container/image pickers
- `zshrc/ssh.zsh` — SSH passthrough (`s`), fzf host picker (`ss`), key bootstrap (`sinit`), agent auto-load
- `zshrc/funcs.zsh` — misc utilities (`redact-json`, `pk`, `port`, `py_watch`, `denter`)
- `zshrc/local/*.zsh` — machine-specific extensions (gitignored, not tracked)
- `configs/AGENTS.md` — global Claude Code / agent rules (symlinked to `~/.claude/CLAUDE.md`)
- `configs/claude-permissions.json` — Claude Code allow/deny lists, merged into `~/.claude/settings.json` by `cinit.py`
- `tests/` — zsh test suite; `tests/run.zsh [filter]` runs it
- `configs/agents/skills/*/SKILL.md` — hand-authored agent skills; `cinit` symlinks each into both `~/.claude/skills/` and `~/.codex/skills/` (npx-managed skills in `~/.agents/skills/` are left untouched)
- `configs/tmux.conf` — tmux config (extended-keys, shift+enter support)
- `configs/vimrc` — vim config (persistent undo)

## Conventions

- **Help functions as passthroughs**: `g`, `tm`, `ts`, `c`, `co`, `d`, `v`, `s`, `z` print help when called with no args, otherwise delegate to the underlying tool (e.g., `g log` → `git log`). Each domain's help text is the canonical alias reference.
- **fzf pattern**: Functions that accept an optional argument use it directly if given, otherwise pipe a list into `__pick` (e.g., `gsw`, `tms`, `gdb`, `dlog`). Never call `__fzf` directly — `__pick` owns the empty/cancelled contract, returning non-zero so callers can `|| return 1`.
- **Testing**: `tests/run.zsh`. Modules invoke external tools as a bare command word — that word is the seam. `stub git` shadows it with a recording function; assert with `assert_called`. Avoid `xargs` in module code: it spawns a new process, so stubs do not apply and tests hit the real binary.
- **`__git_default_branch()`**: Auto-detects `main` vs `master` — used by `gmm`, `gdm`, `gswm`.
- **Platform abstraction**: Use `clipcopy`/`clippaste` instead of `pbcopy`/`pbpaste`, and `__notify` instead of `osascript`. Platform helpers live in `zshrc/platform.zsh`.
- **Zoxide navigation**: `j`/`ji` for directory jumping (uses `--cmd j` to avoid conflict with `z` help function).

## Claude Rules

- To update global Claude Code rules, edit `configs/AGENTS.md` — **never** edit `~/.claude/CLAUDE.md` directly (it is a symlink to this file).

## Tool Preferences

- Prefer the **Edit tool** over `sed` for file modifications.
- Prefer the **Read tool** over `cat`/`head`/`tail` for reading files.
- Prefer the **Write tool** over `echo`/`cat` redirection for creating files.

## Setup

`zinit` bootstraps a new machine. On macOS: installs xcode tools, homebrew, brew packages (git, fzf, tmux, nvm, python, claude-code, colima, docker, zsh-autosuggestions, zsh-syntax-highlighting, zoxide, mosh). On Ubuntu: apt packages + nvm install script + claude-code via npm. Both ensure Node LTS/npm/npx through nvm. Run `ainit` separately for Claude settings/hooks and optional Claude/Codex skills/plugins.
