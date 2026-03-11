#!/bin/sh
# Prints non-zero queue counts for tmux status bar: Prompt:N Idle:N Thinking:N Paused:N
D=$HOME/.claude/queue
p=0 i=0 t=0 s=0

for f in "$D"/*; do
  [ -f "$f" ] || continue
  n="${f##*/}"
  tmux has-session -t "$n" 2>/dev/null || continue
  read x < "$f"
  case "$x" in
    prompt)   p=$((p+1)) ;;
    thinking) t=$((t+1)) ;;
    paused)   s=$((s+1)) ;;
    *)        i=$((i+1)) ;;
  esac
done

[ $p -gt 0 ] && printf "Prompt:%d " $p
[ $i -gt 0 ] && printf "Idle:%d " $i
[ $t -gt 0 ] && printf "Thinking:%d " $t
[ $s -gt 0 ] && printf "Paused:%d " $s
