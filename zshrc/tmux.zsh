__tmux_session_exists() {
  tmux has-session -t "$1" 2>/dev/null
}

__tmux_jump() {
  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$1"
  else
    tmux attach -t "$1"
  fi
}

__tmux_new_session() {
  local session="$1" cwd="${2:-}" cmd="${3:-}"
  local args=(-ds "$session")
  [[ -n "$cwd" ]] && args+=(-c "$cwd")

  if [[ -n "$cmd" ]]; then
    tmux new-session "${args[@]}" "$cmd"
  else
    tmux new-session "${args[@]}"
  fi
}

__tmux_ensure_session() {
  local session="$1" cwd="${2:-}" cmd="${3:-}"
  if ! __tmux_session_exists "$session"; then
    __tmux_new_session "$session" "$cwd" "$cmd" || return 1
  fi
  __tmux_jump "$session"
}

__tmux_kill_session() {
  tmux kill-session -t "$1" 2>/dev/null
}

tm() {
  if [[ $# -gt 0 ]]; then
    tmux "$@"
    return
  fi
  cat <<'EOF'
tmux aliases:
  sessions
    tmb  background command, notify on done
    tmd  detach
    tmk  kill session (fzf)
    tml  list-sessions
    tmn  new or switch session <name>
    tms  switch session (fzf)

  panes
    tmrpd  resize pane down  5
    tmrpl  resize pane left  5
    tmrpr  resize pane right 5
    tmrpu  resize pane up    5

  keybindings (ctrl+b …)
    "      split horizontal
    %      split vertical
    ,      rename window
    [      scroll / copy mode
    arrow  switch pane
    c      new window
    d      detach
    n / p  next / prev window
    space  command palette
    v      voice recording popup
    w      window list
    x      kill pane
    z      zoom pane

  settings
    tminit  symlink ~/.tmux.conf from repo
    set -g mouse on
EOF
}

## symlink ~/.tmux.conf → repo config
tminit() {
  ln -sf ~/dev/dotfiles/configs/tmux.conf ~/.tmux.conf
  echo "symlinked ~/dev/dotfiles/configs/tmux.conf → ~/.tmux.conf"
  tmux source-file ~/.tmux.conf 2>/dev/null && echo "config reloaded"
}

# simple aliases
alias tml='tmux list-sessions'
alias tmd='tmux detach'
alias tmrpu='tmux resize-pane -U 5'
alias tmrpd='tmux resize-pane -D 5'
alias tmrpl='tmux resize-pane -L 5'
alias tmrpr='tmux resize-pane -R 5'

## create or switch to named session (avoids nesting)
tmn() {
  if [[ -z "$1" ]]; then
    echo "usage: tmn <name>" && return 1
  fi
  __tmux_ensure_session "$1"
}

_tmux_pick_session() {
  tmux list-sessions -F '#{session_name}' 2>/dev/null \
    | __fzf --prompt="${1:-session> }"
}

## switch session (inline or fzf select)
tms() {
  local session=${1:-$(_tmux_pick_session 'switch session> ')}
  [[ -z "$session" ]] && return 1
  __tmux_jump "$session"
}

## background command with notification on completion
_tmb_notify() {
  local rc=$1 cmd=$2 session=$3
  local tag="DONE" sound="Glass"
  [[ $rc -ne 0 ]] && tag="FAILED" && sound="Basso"
  tmux rename-session -t "$session" "${session}_${tag}" 2>/dev/null
  __notify "$tag" "$cmd" "$sound"
  clear
  echo "[tmb] $tag (exit $rc): $cmd"
  echo "press any key to close"
  read -k1
  exit
}

tmb() {
  [[ -z "$1" ]] && echo "usage: tmb <command...>" && return 1
  local name="bg-${(j:_:)${(@s: :)*}[1,3]}"
  if __tmux_session_exists "$name"; then
    echo "already running $name" && return 1
  fi
  __tmux_new_session "$name" || return 1
  tmux send-keys -t "$name" "$*; _tmb_notify \$? '${*//\'/\'\\\'\'}' '$name'" Enter
  echo "running in '$name'"
}

## kill session (inline or fzf select)
tmk() {
  local session=${1:-$(_tmux_pick_session 'kill session> ')}
  [[ -z "$session" ]] && return 1
  __tmux_kill_session "$session"
}
