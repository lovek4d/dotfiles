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
  __link_config "$HOME/dev/dotfiles/configs/AGENTS.md" "$HOME/.claude/CLAUDE.md" || return 1
  python3 "$HOME/dev/dotfiles/scripts/cinit.py" || return 1
}

alias cn='claude'
alias cq='claude --print'
alias cr='claude --resume'
alias cqh='claude --print --model haiku'
alias cqs='claude --print --model sonnet'
alias cqo='claude --print --model opus'
alias cup='claude update'
