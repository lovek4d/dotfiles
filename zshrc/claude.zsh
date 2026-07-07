c() {
  if [[ $# -gt 0 ]]; then
    claude "$@"
    return
  fi
  cat <<'EOF'
claude aliases:
  core
    cn     claude (new interactive session)
    cq     claude --print (quick)
    cr     claude --resume
  quick + model
    cqh    claude --print --model haiku
    cqo    claude --print --model opus
    cqs    claude --print --model sonnet
  workflow
    cgt    worktree + tmux + claude (attaches if session exists)
    cgtd   alias for agtd (destroy agent worktree + tmux session)
    cup    upgrade claude-code
    cinit  setup ~/.claude/settings.json
EOF
}

cinit() {
  ln -sf "$HOME/dev/dotfiles/configs/AGENTS.md" "$HOME/.claude/CLAUDE.md" || return 1
  python3 "$HOME/dev/dotfiles/scripts/cinit.py" || return 1
  echo "claude settings.json updated (git allowlist + no-paths hook)"
  echo "~/.claude/CLAUDE.md -> $HOME/dev/dotfiles/configs/AGENTS.md"
  echo "~/.claude/hooks/no-paths.py -> $HOME/dev/dotfiles/scripts/claude/hooks/no-paths.py"
}

alias cn='claude'
alias cq='claude --print'
alias cr='claude --resume'
alias cqh='claude --print --model haiku'
alias cqs='claude --print --model sonnet'
alias cqo='claude --print --model opus'
alias cup='claude update'
