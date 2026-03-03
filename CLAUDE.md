# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Zsh dotfiles for macOS and Ubuntu. Sourced via `source $HOME/dev/dotfiles/zshrc/init.zsh` in `~/.zshrc`.

## Structure

- `zshrc/platform.zsh` — platform detection (`__is_macos`/`__is_linux`), clipboard (`clipcopy`/`clippaste`), and notification (`__notify`) abstractions
- `zshrc/init.zsh` — entrypoint; sources platform.zsh first, sets up completions, sources all other zshrc files, defines bootstrap (`zinit`) and general aliases, loads zsh plugins
- `zshrc/git.zsh` — git aliases and fzf-powered branch/stash/worktree helpers
- `zshrc/tmux.zsh` — tmux aliases, keybindings, and Claude queue status bar integration
- `zshrc/claude.zsh` — Claude Code aliases, worktree workflow (`cgt`/`cgtd`), and queue system (`cw`/`cwf`/`cwd`/`cinit`)
- `zshrc/vim.zsh` — vim config (sets `VIMINIT` to point at repo)
- `zshrc/funcs.zsh` — misc utilities (e.g., `redact-json`)
- `configs/tmux.conf` — tmux config (extended-keys, shift+enter support)
- `configs/vimrc` — vim config (persistent undo)

## Conventions

- **Help functions as passthroughs**: `g`, `t`, `c`, `v`, `z` print help when called with no args, otherwise delegate to the underlying tool (e.g., `g log` → `git log`). Each domain's help text is the canonical alias reference.
- **fzf pattern**: Functions that accept an optional argument use it directly if given, otherwise present an fzf selector (e.g., `gsw`, `ts`, `gmn`, `gdb`).
- **`__git_default_branch()`**: Auto-detects `main` vs `master` — used by `gmm`, `gdm`, `gswm`.
- **Platform abstraction**: Use `clipcopy`/`clippaste` instead of `pbcopy`/`pbpaste`, and `__notify` instead of `osascript`. Platform helpers live in `zshrc/platform.zsh`.

## Queue System

File-based state in `~/.claude/queue/` tracks Claude Code session status across tmux sessions. Four priority levels: `prompt` > `idle` > `thinking` > `paused`. Hooks are written to `~/.claude/settings.json` by `cinit`. The tmux status bar shows counts (P/I/T/S) and `cwf` auto-focuses the highest-priority session.

## Setup

`zinit` bootstraps a new machine. On macOS: installs xcode tools, homebrew, brew packages (git, fzf, tmux, nvm, python, claude-code, colima, docker, zsh-autosuggestions, zsh-syntax-highlighting). On Ubuntu: apt packages + nvm install script + claude-code via npm. Both finish with `tinit` and `cinit`.
