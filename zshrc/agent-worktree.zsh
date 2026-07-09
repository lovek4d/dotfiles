__agent_worktree_session() {
  local root="$1" target="$2" local_branch="$3" launch="$4" cleanup="${5:-1}"
  local session="$(__git_branch_slug "$local_branch")"
  local cmd="$launch"
  [[ "$cleanup" == 1 ]] && cmd="${launch}; cd '${root}' && git worktree remove '${target}'"

  __tmux_ensure_session "$session" "$target" "$cmd"
}

__agent_worktree() {
  local launch="$1" name="$2" label="$3" branch="$4"

  if [[ "$branch" == "-h" || "$branch" == "--help" ]]; then
    cat <<EOF
$name - create a worktree + tmux session + launch $label

usage: $name [branch-name]

  If branch-name is given, creates or reuses that branch.
  New branches start from the current branch.
  If omitted, fzf-selects from existing branches.

  If a tmux session already exists for the branch, attaches to it.
  Use agtd to tear down a worktree + tmux session.
EOF
    return 0
  fi

  local root
  root="$(__git_repo_root 2>/dev/null)" || { echo "not in a git repo"; return 1; }

  if [[ -z "$branch" ]]; then
    branch=$(__git_branch_list | __fzf --prompt='worktree branch> ')
    [[ -z "$branch" ]] && return 1
  fi

  local local_branch="$branch" start_point=""
  __git_normalize_branch "$branch" local_branch start_point
  [[ -z "$start_point" ]] && start_point=HEAD

  local session="$(__git_branch_slug "$local_branch")"
  if __tmux_session_exists "$session"; then
    __tmux_jump "$session"
    return 0
  fi

  local target="$(__git_worktree_path "$local_branch" "$root")"
  local cleanup=1
  [[ -n "$(__git_worktree_for_branch "$local_branch")" ]] && cleanup=0
  mkdir -p "$(dirname "$target")"
  target="$(__git_worktree_add "$local_branch" "$target" "$start_point")" || return 1
  __agent_worktree_session "$root" "$target" "$local_branch" "$launch" "$cleanup"
}

cgt() { __agent_worktree claude cgt Claude "$1"; }
cogt() { __agent_worktree codex cogt Codex "$1"; }

agtd() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'EOF'
agtd - destroy an agent worktree + tmux session

usage: agtd [branch-name]

  If branch-name is omitted, fzf-selects from active worktrees.
  The branch itself is left intact.
EOF
    return 0
  fi

  git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "not in a git repo" >&2; return 1; }

  local branch="$1"
  if [[ -z "$branch" ]]; then
    branch=$(__git_worktree_branches | __fzf --prompt='destroy worktree> ')
    [[ -z "$branch" ]] && return 1
  fi

  local wt_path="$(__git_resolve_worktree '' "$branch")" || return 1
  branch="$(__git_worktree_branch_for_path "$wt_path")"
  [[ -z "$branch" ]] && echo "no branch for worktree: $wt_path" >&2 && return 1
  local session="$(__git_branch_slug "$branch")"

  __tmux_kill_session "$session"
  git worktree remove "$wt_path"
  echo "destroyed worktree: $branch ($wt_path)"
}

alias cgtd=agtd

_cgt() { __git_complete_as switch }
compdef _cgt cgt cogt

_agtd() { _complete_worktree_branches }
compdef _agtd agtd cgtd
