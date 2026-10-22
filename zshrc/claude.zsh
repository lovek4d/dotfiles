c() {
  if [[ $# -gt 0 ]]; then
    claude "$@"
    return
  fi
  cat <<'EOF'
claude aliases:
  core
    cn     claude (new interactive session)
    cq     claude --print (quick, streams output)
    cr     claude --resume
  quick + model
    cqh    cq --model haiku
    cqo    cq --model opus
    cqs    cq --model sonnet
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

## --print buffers the whole answer; stream-json with partial messages emits
## text deltas as they arrive, so print those instead (plus the final result if
## it is an error, which never arrives as a delta)
cq() {
  claude --print --output-format stream-json --include-partial-messages --verbose "$@" |
    jq --unbuffered -j '
      if .type == "stream_event" and .event.delta.type == "text_delta" then .event.delta.text
      elif .type == "result" and .is_error then .result
      else empty end'
  local rc=${pipestatus[1]}
  print
  return $rc
}

alias cn='claude'
alias cr='claude --resume'
alias cqh='cq --model haiku'
alias cqs='cq --model sonnet'
alias cqo='cq --model opus'
alias cup='claude update'
