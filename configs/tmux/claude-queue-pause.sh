#!/bin/sh
# Demotes current tmux session to paused state
S=$(tmux display-message -p "#{session_name}")
f="$HOME/.claude/queue/$S"

if [ -f "$f" ]; then
  read t < "$f"
  case "$t" in
    paused)
      tmux display-message "already paused: $S"
      ;;
    *)
      echo paused > "$f"
      tmux display-message "paused: $S (was $t)"
      ;;
  esac
else
  tmux display-message "not in queue: $S"
fi
