#!/bin/sh
# Lists queued sessions grouped by priority, pipes to fzf, switches to selected session
D=~/.claude/queue
p="" i="" t="" s=""

for f in "$D"/*; do
  [ -f "$f" ] || continue
  n="${f##*/}"
  tmux has-session -t "$n" 2>/dev/null || continue
  read x < "$f"
  case "$x" in
    prompt)   p="$p[prompt]   $n\n" ;;
    thinking) t="$t[thinking] $n\n" ;;
    paused)   s="$s[paused]   $n\n" ;;
    *)        i="$i[idle]     $n\n" ;;
  esac
done

printf "%b%b%b%b" "$p" "$i" "$t" "$s" \
  | fzf --prompt="queue> " --reverse \
  | sed 's/^\[[a-z]*\] *//' \
  | xargs -I{} tmux switch-client -t {}
