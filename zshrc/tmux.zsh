__tmux_jump() {
  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$1"
  else
    tmux attach -t "$1"
  fi
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
    tmn  new session <name>
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
    ctrl+q claude queue popup
    ctrl+w demote session to paused
    d      detach
    n / p  next / prev window
    space  command palette
    w      window list
    x      kill pane
    z      zoom pane

  status bar
    P:N    prompt (needs input)   S:N  shelved/paused
    I:N    idle (results ready)   T:N  thinking (working)

  settings
    tminit  symlink ~/.tmux.conf from repo
    set -g mouse on
EOF
}

## symlink ~/.tmux.conf → repo config
tminit() {
  ln -sf ~/dev/dotfiles/configs/tmux.conf ~/.tmux.conf
  echo "symlinked ~/dev/dotfiles/configs/tmux.conf → ~/.tmux.conf"
  [[ -n "$TMUX" ]] && tmux source-file ~/.tmux.conf && echo "config reloaded"
}

# simple aliases
alias tml='tmux list-sessions'
alias tmd='tmux detach'
alias tmrpu='tmux resize-pane -U 5'
alias tmrpd='tmux resize-pane -D 5'
alias tmrpl='tmux resize-pane -L 5'
alias tmrpr='tmux resize-pane -R 5'

## create named session (avoids nesting)
tmn() {
  if [[ -z "$1" ]]; then
    echo "usage: tmn <name>" && return 1
  fi
  tmux new-session -ds "$1" && __tmux_jump "$1"
}

## switch session (inline or fzf select)
tms() {
  if [[ -n "$1" ]]; then
    __tmux_jump "$1"
  else
    local session
    session=$(tmux list-sessions -F '#{session_name}' 2>/dev/null \
      | fzf --prompt='switch session> ' --height=40% --reverse)
    [[ -z "$session" ]] && return 1
    __tmux_jump "$session"
  fi
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
  local name="bg-$(echo "$*" | awk '{for(i=1;i<=3&&i<=NF;i++) printf (i>1?"_":"") $i}')"
  if tmux has-session -t "$name" 2>/dev/null; then
    echo "already running $name" && return 1
  fi
  tmux new-session -ds "$name" \; \
    send-keys -t "$name" "$*; _tmb_notify \$? '${*//\'/\'\\\'\'}' '$name'" Enter
  echo "running in '$name'"
}

## kill session (inline or fzf select)
tmk() {
  if [[ -n "$1" ]]; then
    tmux kill-session -t "$1"
  else
    local session
    session=$(tmux list-sessions -F '#{session_name}' 2>/dev/null \
      | fzf --prompt='kill session> ' --height=40% --reverse)
    [[ -z "$session" ]] && return 1
    tmux kill-session -t "$session"
  fi
}

## claude queue: keybindings + status bar
if [[ -n "$TMUX" ]]; then
  # ctrl+b ctrl+q → popup with waiting sessions (4-bucket priority)
  tmux bind-key C-q popup -E -w 60 -h 20 \
    'D=~/.claude/queue; p=""; i=""; t=""; s=""; for f in "$D"/*; do [ -f "$f" ] || continue; n="${f##*/}"; tmux has-session -t "$n" 2>/dev/null || continue; read x < "$f"; case "$x" in prompt) p="$p[prompt]   $n
";; thinking) t="$t[thinking] $n
";; paused) s="$s[paused]   $n
";; *) i="$i[idle]     $n
";; esac; done; printf "%s%s%s%s" "$p" "$i" "$t" "$s" | fzf --prompt="queue> " --reverse | sed "s/^\[[a-z]*\] *//" | xargs -I{} tmux switch-client -t {}'

  # ctrl+b ctrl+w → demote current session to paused
  tmux bind-key C-w run-shell \
    'S=$(tmux display-message -p "#{session_name}"); f="$HOME/.claude/queue/$S"; if [ -f "$f" ]; then read t < "$f"; case "$t" in paused) tmux display-message "already paused: $S";; *) echo paused > "$f"; tmux display-message "paused: $S (was $t)";; esac; else tmux display-message "not in queue: $S"; fi'

  # status bar: show session name + git branch
  tmux set-option -g status-left \
    '#[fg=green]#S #[default]#(cd "#{pane_current_path}" && git branch --show-current 2>/dev/null | sed "s/.*/ [&]/") '

  # status bar: show P:N I:N T:N S:N (non-zero only)
  tmux set-option -g status-interval 2
  tmux set-option -g status-right \
    '#(D=$HOME/.claude/queue; p=0; i=0; t=0; s=0; for f in "$D"/*; do [ -f "$f" ] || continue; n="${f##*/}"; tmux has-session -t "$n" 2>/dev/null || continue; read x < "$f"; case "$x" in prompt) p=$((p+1));; thinking) t=$((t+1));; paused) s=$((s+1));; *) i=$((i+1));; esac; done; [ $p -gt 0 ] && printf "P:%d " $p; [ $i -gt 0 ] && printf "I:%d " $i; [ $t -gt 0 ] && printf "T:%d " $t; [ $s -gt 0 ] && printf "S:%d " $s) %H:%M'
fi
