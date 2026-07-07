__cgt_session() {
  local root="$1" target="$2" local_branch="$3" launch="${4:-claude --permission-mode plan}"
  local session="${local_branch//\//-}"
  local cmd="${launch}; cd '${root}' && git worktree remove '${target}'"

  if [[ -n "$TMUX" ]]; then
    tmux new-session -ds "$session" -c "$target" "$cmd"
    tmux switch-client -t "$session"
  else
    tmux new-session -s "$session" -c "$target" "$cmd"
  fi
}

_cgtb_notify() {
  local rc=$1 session=$2 root=$3 target=$4 label="${5:-cgtb}"
  local tag="DONE" sound="Glass"
  [[ $rc -ne 0 ]] && tag="FAILED" && sound="Basso"
  __notify "$tag" "$label: $session" "$sound"
  clear
  echo "[$label] $tag (exit $rc)"
  echo "review changes, then press any key to remove worktree"
  read -k1
  cd "$root" && git worktree remove --force "$target"
  exit
}

c() {
  if [[ $# -gt 0 ]]; then
    claude --permission-mode plan "$@"
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
    cgtb   worktree + background claude + notify (inline message)
    cgtf   worktree from fzf-selected base branch
    cgtd   destroy worktree + tmux session
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

alias cn='claude --permission-mode plan'
alias cq='claude --print'
alias cr='claude --resume --permission-mode plan'
alias cqh='claude --print --model haiku'
alias cqs='claude --print --model sonnet'
alias cqo='claude --print --model opus'
alias cup='claude update'

cgt() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'EOF'
cgt — create a worktree + tmux session + launch claude code

usage: cgt [branch-name]

  If branch-name is given, creates (or reuses) that branch.
  New branches start from the default branch (main/master).
  If omitted, fzf-selects from existing branches.

  If a tmux session already exists for the branch, attaches to it.

  Creates a git worktree, opens a tmux session named after
  the branch, and starts claude code inside it.

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

  __cgt_session "$root" "$target" "$local_branch"
}

cgtb() {
  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    cat <<'EOF'
cgtb — worktree + background claude with inline message + notify on done

usage: cgtb <message>

  Auto-names the branch from the message (bg/<slug>).
  Runs claude --print "<message>" in a detached tmux session.
  Sends a desktop notification when done.

  Does NOT switch to the new session — runs in background.
  Switch to the session to review, then press any key to teardown.
  Use cgt to attach to an existing worktree session.
  Use cgtf to create a worktree from a specific base branch.
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
    send-keys -t "$session" "claude --print '$escaped_msg'; _cgtb_notify \$? '$session' '$root' '$target'" Enter

  echo "backgrounded in session: $session"
}

cgtf() {
  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    cat <<'EOF'
cgtf — worktree + tmux + claude from a specific base branch

usage: cgtf <new-branch>

  Creates a new branch from an fzf-selected base branch.
  Otherwise identical to cgt.
EOF
    return 0
  fi

  local local_branch="$1"

  if git show-ref --verify --quiet "refs/heads/$local_branch"; then
    echo "branch '$local_branch' already exists (use cgt to reuse it)"
    return 1
  fi

  local base
  base=$(__git_branch_list | __fzf --prompt='base branch> ')
  [[ -z "$base" ]] && return 1

  cgt "$local_branch" "$base"
}

cgtd() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'EOF'
cgtd — destroy a worktree + tmux session

usage: cgtd

  fzf-selects from active worktrees (excluding the main one),
  kills the associated tmux session, and removes the worktree.

  The branch itself is left intact.

  Inverse of cgt.
EOF
    return 0
  fi

  git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "not in a git repo" >&2; return 1; }

  local selection
  if [[ -n "$1" ]]; then
    selection=$(git worktree list | tail -n +2 | awk -v b="[$1]" '$3==b')
    [[ -z "$selection" ]] && echo "no worktree for branch: $1" >&2 && return 1
  else
    selection=$(git worktree list | tail -n +2 \
      | __fzf --prompt='destroy worktree> ')
    [[ -z "$selection" ]] && return 1
  fi

  local wt_path branch session
  local -a fields=("${(z)selection}")
  local wt_path="$fields[1]" branch="${fields[3]//[\[\]]/}"
  session="${branch//\//-}"

  tmux kill-session -t "$session" 2>/dev/null
  git worktree remove "$wt_path"

  echo "destroyed worktree: $branch ($wt_path)"
}

_cgt() { __git_complete_as switch }
compdef _cgt cgt cgtf

_cgtd() { _complete_worktree_branches }
compdef _cgtd cgtd
