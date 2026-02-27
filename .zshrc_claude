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
    cgt    worktree + tmux + claude
    cgtd   destroy worktree + tmux session
    cup    brew upgrade claude-code
  queue
    cinit  setup ~/.claude/settings.json
    cw     waiting sessions (fzf jump, priority sorted)
    cwd    demote current session (→ paused)
    cwf    auto-focus mode (polls queue, priority cascade)
EOF
}

alias cn='claude'
alias cq='claude --print'
alias cr='claude --resume'
alias cqh='claude --print --model haiku'
alias cqs='claude --print --model sonnet'
alias cqo='claude --print --model opus'
alias cup='brew upgrade claude-code'

cgt() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'EOF'
cgt — create a worktree + tmux session + launch claude code

usage: cgt [branch-name]

  If branch-name is given, creates (or reuses) that branch.
  If omitted, fzf-selects from existing branches.

  Creates a git worktree, opens a tmux session named after
  the branch, and starts claude code inside it.

  On exit, the worktree is automatically removed (unless dirty).
  Use cgtd to manually tear down a worktree + tmux session.
EOF
    return 0
  fi

  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in a git repo"; return 1; }

  # resolve branch: argument or fzf select
  local branch
  if [[ -n "$1" ]]; then
    branch="$1"
  else
    branch=$(git branch -a --format='%(refname:short)' \
      | fzf --prompt='worktree branch> ' --height=40% --reverse)
    [[ -z "$branch" ]] && return 1
  fi

  local base_dir="$(dirname "$root")/$(basename "$root")-worktrees"
  local target="$base_dir/$branch"

  # create worktree: new branch from HEAD if doesn't exist, else use existing
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$target" "$branch"
  else
    git worktree add -b "$branch" "$target"
  fi
  [[ $? -ne 0 ]] && return 1

  # sanitize branch name for tmux session (replace / with -)
  local session="${branch//\//-}"

  # create tmux session: launch claude, then auto-remove worktree on exit
  local cmd="claude; cd '${root}' && git worktree remove '${target}'"

  if [[ -n "$TMUX" ]]; then
    tmux new-session -ds "$session" -c "$target" "$cmd"
    tmux switch-client -t "$session"
  else
    tmux new-session -s "$session" -c "$target" "$cmd"
  fi
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

  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in a git repo"; return 1; }

  local selection
  selection=$(git worktree list | tail -n +2 \
    | fzf --prompt='destroy worktree> ' --height=40% --reverse)
  [[ -z "$selection" ]] && return 1

  local wt_path branch session
  wt_path=$(echo "$selection" | awk '{print $1}')
  branch=$(echo "$selection" | awk '{print $3}' | tr -d '[]')
  session="${branch//\//-}"

  tmux kill-session -t "$session" 2>/dev/null
  git worktree remove "$wt_path"

  echo "destroyed worktree: $branch ($wt_path)"
}

cinit() {
  mkdir -p ~/.claude/queue
  python3 - <<'PYEOF'
import json, os

path = os.path.expanduser("~/.claude/settings.json")
settings = {}
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)

Q = 'D=$HOME/.claude/queue; mkdir -p "$D"; S=$(tmux display-message -p "#{session_name}" 2>/dev/null) || exit 0'

def enqueue(typ, notify=True):
    bell = 'printf "\\a"; tmux display-message "Claude %s: $S" 2>/dev/null' % typ if notify else ':'
    return f"bash -c '{Q}; echo {typ} > \"$D/$S\"; {bell}'"

dequeue = f"bash -c '{Q}; rm -f \"$D/$S\"'"
to_thinking = f"bash -c '{Q}; f=\"$D/$S\"; [ -f \"$f\" ] && read t < \"$f\" && [ \"$t\" = prompt ] && echo thinking > \"$f\"'"

settings["hooks"] = {
    "Notification": [
        {"matcher": "permission_prompt|elicitation_dialog",
         "hooks": [{"type": "command", "command": enqueue("prompt"), "timeout": 5}]},
        {"matcher": "idle_prompt",
         "hooks": [{"type": "command", "command": enqueue("idle"), "timeout": 5}]},
    ],
    "Stop":            [{"hooks": [{"type": "command", "command": enqueue("idle"),             "timeout": 5}]}],
    "PostToolUse":     [{"hooks": [{"type": "command", "command": to_thinking,                 "timeout": 5}]}],
    "UserPromptSubmit":[{"hooks": [{"type": "command", "command": enqueue("thinking", False),  "timeout": 5}]}],
    "SessionEnd":      [{"hooks": [{"type": "command", "command": dequeue,                     "timeout": 5}]}],
}

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF
  echo "claude settings.json updated with queue hooks"
}

cw() {
  local queue_dir="$HOME/.claude/queue"
  [[ ! -d "$queue_dir" ]] && echo "no queue directory (run cinit)" && return 1

  local prompts=() idles=() thinkings=() pauseds=()
  for f in "$queue_dir"/*(.N); do
    local session="${f:t}" typ=""
    if ! tmux has-session -t "$session" 2>/dev/null; then
      rm -f "$f"; continue
    fi
    read -r typ < "$f" 2>/dev/null
    case "$typ" in
      prompt)   prompts+=("$session") ;;
      thinking) thinkings+=("$session") ;;
      paused)   pauseds+=("$session") ;;
      *)        idles+=("$session") ;;  # idle, done, unknown → idle
    esac
  done

  local total=$(( ${#prompts[@]} + ${#idles[@]} + ${#thinkings[@]} + ${#pauseds[@]} ))
  if [[ $total -eq 0 ]]; then
    echo "no sessions waiting"
    return 0
  fi

  echo "$total session(s) waiting"
  local entries=()
  for s in "${prompts[@]}";  do entries+=("[prompt]   $s"); done
  for s in "${idles[@]}";    do entries+=("[idle]     $s"); done
  for s in "${thinkings[@]}"; do entries+=("[thinking] $s"); done
  for s in "${pauseds[@]}";  do entries+=("[paused]   $s"); done

  if [[ -n "$TMUX" ]]; then
    local choice
    choice=$(printf '%s\n' "${entries[@]}" \
      | fzf --prompt='jump to> ' --height=40% --reverse \
      | sed 's/^\[[a-z]*\] *//')
    [[ -n "$choice" ]] && tmux switch-client -t "$choice"
  else
    printf '  %s\n' "${entries[@]}"
  fi
}

cwf() {
  local queue_dir="$HOME/.claude/queue"
  [[ ! -d "$queue_dir" ]] && echo "no queue directory (run cinit)" && return 1
  [[ -z "$TMUX" ]] && echo "cwf must be run inside a tmux session" && return 1

  local cwf_tty=$(tmux display-message -p '#{client_tty}')
  local showing=""
  echo "auto-focus mode (ctrl-c to stop)"
  while true; do
    local best="" first_idle="" first_thinking="" first_paused=""
    for f in "$queue_dir"/*(.N); do
      local session="${f:t}" typ=""
      if ! tmux has-session -t "$session" 2>/dev/null; then
        rm -f "$f"; continue
      fi
      read -r typ < "$f" 2>/dev/null
      case "$typ" in
        prompt)   best="$session"; break ;;
        thinking) [[ -z "$first_thinking" ]] && first_thinking="$session" ;;
        paused)   [[ -z "$first_paused" ]]   && first_paused="$session" ;;
        *)        [[ -z "$first_idle" ]]      && first_idle="$session" ;;  # idle, done, unknown
      esac
    done
    [[ -z "$best" ]] && best="${first_idle:-${first_thinking:-$first_paused}}"

    if [[ -n "$best" && "$best" != "$showing" ]]; then
      tmux switch-client -c "$cwf_tty" -t "$best"
      showing="$best"
      echo "switched to: $best"
    elif [[ -z "$best" ]]; then
      showing=""
    fi

    sleep 1
  done
}

cwd() {
  [[ -z "$TMUX" ]] && echo "cwd must be run inside a tmux session" && return 1
  local session
  session=$(tmux display-message -p '#{session_name}')
  local f="$HOME/.claude/queue/$session"
  if [[ -f "$f" ]]; then
    local typ=""
    read -r typ < "$f" 2>/dev/null
    if [[ "$typ" == "paused" ]]; then
      echo "already paused: $session"
    else
      echo paused > "$f"
      echo "paused: $session (was $typ)"
    fi
  else
    echo "not in queue: $session"
  fi
}
