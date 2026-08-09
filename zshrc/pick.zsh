# Interactive selection — the one seam between a list and a chosen item.
# Every domain module (git, docker, tmux, tailscale, ssh) picks through here.

# fzf base wrapper
__fzf() { fzf --height=40% --reverse --no-sort "$@"; }

## select from a list on stdin; prints the selection, non-zero if empty/cancelled
## usage: <list producer> | __pick <prompt> [fzf-args...]
__pick() {
  local prompt="$1"; shift
  local selection
  selection="$(__fzf --prompt="$prompt" "$@")" || return 1
  [[ -z "$selection" ]] && return 1
  print -r -- "$selection"
}
