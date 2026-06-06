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
    cogtb  worktree + background codex + notify (inline message)
    cogtf  worktree from fzf-selected base branch
    coup   upgrade codex
EOF
}

alias con='codex'
alias coq='codex exec'
alias cor='codex resume'
alias coup='codex update'

cogt() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'EOF'
cogt — create a worktree + tmux session + launch codex

usage: cogt [branch-name]

  If branch-name is given, creates (or reuses) that branch.
  New branches start from the default branch (main/master).
  If omitted, fzf-selects from existing branches.

  If a tmux session already exists for the branch, attaches to it.

  Creates a git worktree, opens a tmux session named after
  the branch, and starts codex inside it.

  On exit, the worktree is automatically removed (unless dirty).
  Use cgtd to manually tear down a worktree + tmux session.
EOF
    return 0
  fi

  local root
  root="$(__git_repo_root 2>/dev/null)" || { echo "not in a git repo"; return 1; }

  # resolve branch: argument or fzf select
  local branch
  if [[ -n "$1" ]]; then
    branch="$1"
  else
    branch=$(__git_branch_list | __fzf --prompt='worktree branch> ')
    [[ -z "$branch" ]] && return 1
  fi

  # strip remote prefix (e.g. origin/foo → foo), or use explicit start point from $2
  local local_branch="$branch" start_point=""
  __git_normalize_branch "$branch" local_branch start_point "${2:-}"

  local session="${local_branch//\//-}"

  # attach if session already exists
  if tmux has-session -t "$session" 2>/dev/null; then
    if [[ -n "$TMUX" ]]; then
      tmux switch-client -t "$session"
    else
      tmux attach-session -t "$session"
    fi
    return 0
  fi

  local target="$(__git_worktree_path "$local_branch" "$root")"
  mkdir -p "$(dirname "$target")"
  __git_worktree_add "$local_branch" "$target" "$start_point" || return 1

  __cgt_session "$root" "$target" "$local_branch" 'codex'
}

cogtb() {
  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    cat <<'EOF'
cogtb — worktree + background codex with inline message + notify on done

usage: cogtb <message>

  Auto-names the branch from the message (bg/<slug>).
  Runs codex exec "<message>" in a detached tmux session.
  Sends a desktop notification when done.

  Does NOT switch to the new session — runs in background.
  Switch to the session to review, then press any key to teardown.
  Use cogt to attach to an existing worktree session.
  Use cogtf to create a worktree from a specific base branch.
EOF
    return 0
  fi

  local msg="$*"
  local root
  root="$(__git_repo_root 2>/dev/null)" || { echo "not in a git repo" >&2; return 1; }

  local slug
  slug="$(printf '%s' "$msg" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//' | sed 's/-*$//')"
  local local_branch="bg/${slug:0:40}"

  if git show-ref --verify --quiet "refs/heads/$local_branch"; then
    local_branch="${local_branch}-$(date +%s)"
  fi

  local target
  target="$(__git_worktree_path "$local_branch" "$root")"
  mkdir -p "$(dirname "$target")"
  __git_worktree_add "$local_branch" "$target" "" || return 1

  local session="${local_branch//\//-}"
  local escaped_msg="${msg//\'/\'\\\'\'}"

  tmux new-session -ds "$session" -c "$target" \; \
    send-keys -t "$session" "codex exec '$escaped_msg'; _cgtb_notify \$? '$session' '$root' '$target' cogtb" Enter

  echo "backgrounded in session: $session"
}

cogtf() {
  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    cat <<'EOF'
cogtf — worktree + tmux + codex from a specific base branch

usage: cogtf <new-branch>

  Creates a new branch from an fzf-selected base branch.
  Otherwise identical to cogt.
EOF
    return 0
  fi

  local local_branch="$1"

  if git show-ref --verify --quiet "refs/heads/$local_branch"; then
    echo "branch '$local_branch' already exists (use cogt to reuse it)"
    return 1
  fi

  local base
  base=$(__git_branch_list | __fzf --prompt='base branch> ')
  [[ -z "$base" ]] && return 1

  cogt "$local_branch" "$base"
}

compdef _cgt cogt cogtf
