#!/bin/sh
# Lists queued sessions grouped by priority, pipes to fzf, switches to selected session
D=~/.claude/queue
p="" i="" t="" s=""

get_recency() {
  local file="$1"
  [ -f "$file" ] || return
  local now mtime seconds_ago

  now=$(date +%s)
  mtime=$(stat -L -f%m "$file" 2>/dev/null || stat -L -c%Y "$file" 2>/dev/null)
  seconds_ago=$((now - mtime))

  if [ "$seconds_ago" -lt 60 ]; then
    printf "%ds" "$seconds_ago"
  elif [ "$seconds_ago" -lt 3600 ]; then
    printf "%dm" $((seconds_ago / 60))
  elif [ "$seconds_ago" -lt 86400 ]; then
    printf "%dh" $((seconds_ago / 3600))
  else
    printf "%dd" $((seconds_ago / 86400))
  fi
}

colorize_recency() {
  local timestamp="$1"
  # Accent color: cyan
  printf "\033[36m%s\033[0m" "$timestamp"
}

for f in "$D"/*; do
  [ -f "$f" ] || continue
  n="${f##*/}"
  tmux has-session -t "$n" 2>/dev/null || continue
  read x < "$f"
  rec=$(colorize_recency "$(get_recency "$f")")
  case "$x" in
    prompt)   p="$p[prompt]   $n  $rec\n" ;;
    thinking) t="$t[thinking] $n  $rec\n" ;;
    paused)   s="$s[paused]   $n  $rec\n" ;;
    *)        i="$i[idle]     $n  $rec\n" ;;
  esac
done

printf "%b%b%b%b" "$p" "$i" "$t" "$s" \
  | fzf --prompt="queue> " --reverse \
  | awk '{print $2}' \
  | xargs -I{} tmux switch-client -t {}
