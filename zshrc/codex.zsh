co() {
  if [[ $# -gt 0 ]]; then
    codex "$@"
    return
  fi
  cat <<'EOF'
codex aliases:
  core
    con    codex (new interactive session)
    coq    codex exec (quick / non-interactive)
    cor    codex resume
  workflow
    cogt   worktree + tmux + codex (attaches if session exists)
    agtd   destroy agent worktree + tmux session
    coup   upgrade codex
EOF
}

alias con='codex'
alias coq='codex exec'
alias cor='codex resume'
alias coup='codex update'
