# helpers
__git_fzf_branch() {
  local cmd=$1 prompt=$2; shift 2
  if [[ -n "$1" ]]; then
    git ${=cmd} "$@"
  else
    local branch
    branch=$(__git_branch_list | __fzf --prompt="$prompt")
    [[ -n "$branch" ]] && git ${=cmd} "$branch"
  fi
}

__git_fzf_local_branch() {
  local prompt="$1"; shift
  git branch --format='%(refname:short)' | sort \
    | __fzf --prompt="$prompt" "$@"
}

__git_worktree_branches() {
  git worktree list --porcelain 2>/dev/null | awk '/^branch / {sub("refs/heads/", "", $2); print $2}'
}

__git_resolve_worktree() {
  local prompt="$1" branch="$2"
  if [[ -z "$branch" ]]; then
    branch=$(__git_worktree_branches | __fzf --prompt="$prompt")
    [[ -z "$branch" ]] && return 1
  fi
  local wt="$(__git_worktree_for_branch "$branch")"
  [[ -z "$wt" ]] && echo "no worktree for branch: $branch" >&2 && return 1
  echo "$wt"
}

__git_apply_worktree_diff() {
  local wt="$1"
  git -C "$wt" diff HEAD | git apply || return 1
  git -C "$wt" ls-files --others --exclude-standard | while read -r f; do
    mkdir -p "$(dirname "$f")"
    cp "$wt/$f" "$f"
  done
}

__git_stash_fzf() {
  local action=$1 prompt=$2; shift 2
  local entry
  entry=$(git stash list | __fzf --prompt="$prompt")
  [[ -z "$entry" ]] && return 1
  git stash $action "$@" "${entry%%:*}"
}

__git_branch_list() {
  {
    git branch --format='%(refname:short)' | sort
    git branch --remotes --format='%(refname:short)' | grep '/' | sort
  } | awk '
    !/\// { seen[$0]++; print; next }
    { b=$0; sub(/^[^\/]+\//, "", b); if (!seen[b]) print }
  '
}

__git_default_branch() {
  local b
  b="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | cut -d/ -f2)"
  [[ -z "$b" ]] && b="$(git branch --list main master | head -1 | tr -d ' *')"
  echo "${b:-main}"
}

# setup
ginit() {
  local name email changed=0
  name="$(git config --global user.name)"
  email="$(git config --global user.email)"
  if [[ -z "$name" ]]; then
    printf "name: " && read -r name
    [[ -z "$name" ]] && echo "name required" && return 1
    git config --global user.name "$name"
    changed=1
  fi
  if [[ -z "$email" ]]; then
    printf "email: " && read -r email
    [[ -z "$email" ]] && echo "email required" && return 1
    git config --global user.email "$email"
    changed=1
  fi
  if (( changed )); then
    echo "git config set for $name <$email>"
  else
    echo "git config already set for $name <$email>"
  fi
}

# core
g() {
  if [[ $# -gt 0 ]]; then
    git "$@"
    return
  fi
  cat <<'EOF'
git aliases:
  core
    ga     git add
    gaa    git add .
    gfal   git fetch --all --prune
    gpl    git pull --ff-only
    gps    git push
    gst    git status
  log
    gl     git log
    glff   git log --all-match <file>
    glfs   git log -S <str>
    glg    git log --graph
    glo    git log --oneline
    glp    git log -p <n>
  stash
    gs     git stash
    gsa    git stash apply
    gsaf   stash apply (fzf)
    gsd    git stash drop
    gsdf   stash drop (fzf)
    gsl    git stash list
    gsm    git stash -m
    gsp    git stash pop
    gspf   stash pop (fzf)
    gss    git stash show -p
  commits
    gc     git commit
    gca    git commit --amend
    gcan   amend --no-edit
    gcm    git commit -m
  merging
    gcp    git cherry-pick
    gm     git merge
    gmb    merge branch (fzf)
    gmm    merge upstream main
    gmbn   merge --no-edit (fzf)
    gmbs   merge --squash (fzf)
    gmo    merge -X ours
    gmon   -X ours --no-edit
    gms    merge --squash
    gmt    merge -X theirs
    gmtn   -X theirs --no-edit
    grb    git rebase
  diff
    gd     git diff
    gdc    git diff HEAD~1
    gdcp   copy diff to clipboard
    gdap   apply diff from clipboard
    gdaw   apply from worktree (fzf)
    gdawh  apply from worktree, detach + discard changes (fzf)
    gdb    diff branch (fzf)
    gdm    git diff main
  resets
    grh    git reset --hard
    grhc   git clean -fd
    grs    git reset --soft
  branches
    gbr    git branch
    gco    git checkout
    gdl    delete branch (fzf)
    gpla   pull all repos in cwd
    gsw    switch branch (fzf)
    gswap  swap w/ stash (fzf)
    gswc   git switch --create
    gswd   switch branch detached (fzf)
    gswm   switch to main
    gswmh  switch to main, discard changes
  worktrees
    gwc    create or reuse worktree (fzf)
    gwd    rm worktree (fzf)
    gwl    git worktree list
    gwp    git worktree prune
    gws    cd to worktree (fzf)
    gwsm   cd to main worktree
  setup
    ginit  set git user.name + user.email
EOF
}
alias ga='git add'
alias gaa='git add .'
alias gst='git status'
alias gpl='git pull --ff-only'
alias gps='git push'
alias gfal='git fetch --all --prune'

# log
alias gl='git log'
alias glo='git log --oneline'
alias glg='git log --graph'
alias glp='git log -p' # pass number of commits
alias glfs='git log -S' # pass string
alias glff='git log --all-match' # pass filename

# stash
alias gs='git stash'
alias gsp='git stash pop'
alias gsd='git stash drop'
alias gsm='git stash -m'
alias gsl='git stash list'
alias gsa='git stash apply'
alias gss='git stash show -p'

## stash pop/drop/apply (fzf select)
gspf() { __git_stash_fzf pop   'pop stash> '   "$@"; }
gsdf() { __git_stash_fzf drop  'drop stash> '  "$@"; }
gsaf() { __git_stash_fzf apply 'apply stash> ' "$@"; }

# commits
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'

# merging
alias gm='git merge'
alias gms='git merge --squash'
## merge (inline or fzf select)
gmbn() { __git_fzf_branch 'merge --no-edit' 'merge> ' "$@"; }
gmb() { __git_fzf_branch  'merge'           'merge> ' "$@"; }
gmbs() { __git_fzf_branch 'merge --squash'  'squash merge> ' "$@"; }

alias gmo='git merge -X ours'
alias gmt='git merge -X theirs'
alias gmon='git merge -X ours --no-edit'
alias gmtn='git merge -X theirs --no-edit'
alias gcp='git cherry-pick'
alias grb='git rebase'

## merge upstream (auto-detect main/master)
gmm() {
  local base="$(__git_default_branch)"
  git fetch origin "$base" && git merge "origin/$base" --no-edit
}

# diff
alias gd='git diff'
alias gdc='git diff HEAD~1'
alias gdcp='git diff | clipcopy && echo "Copied diff to clipboard"'
alias gdap='clippaste | git apply && echo "Applied diff from clipboard"'

## apply diff from worktree (fzf select or branch arg)
gdaw() {
  local wt="$(__git_resolve_worktree 'apply from worktree> ' "$1")" || return
  __git_apply_worktree_diff "$wt"
  echo "Applied diff from $wt"
}

## apply from worktree: discard local changes, detach at branch (fzf select or branch arg)
gdawh() {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    branch=$(__git_worktree_branches | __fzf --prompt='apply from worktree (hard)> ')
    [[ -z "$branch" ]] && return 1
  fi
  local wt; wt=$(__git_resolve_worktree '' "$branch") || return 1
  git reset --hard || return 1
  git switch -d "$branch" || return 1
  __git_apply_worktree_diff "$wt"
  echo "Applied all changes from $branch worktree"
}

## diff branch (inline or fzf select)
gdb() { __git_fzf_branch diff 'diff branch> ' "$@"; }

## diff main/master (autodetect)
gdm() { git diff "$(__git_default_branch)"; }

# resets
alias grh='git reset --hard'
alias grhc='git reset --hard && git clean -fd'
alias grs='git reset --soft'

# branches
alias gbr='git branch'
alias gco='git checkout'
alias gswc='git switch --create'

## switch branch (inline or fzf select)
gsw()  { __git_fzf_branch switch      'switch> ' "$@"; }
gswd() { __git_fzf_branch 'switch -d' 'detach> ' "$@"; }

## switch to main/master (autodetect)
gswm() { git switch "$(__git_default_branch)" }

## switch to main/master, discard local changes
gswmh() { git switch -f "$(__git_default_branch)"; }

## swap branch with stash (fzf select)
gswap() {
  local branch
  branch=$(__git_branch_list | __fzf --prompt='swap to> ')
  [[ -z "$branch" ]] && return 1
  git stash -m "switch staging" && git switch "$branch" && git stash pop
}

## delete branches by pattern, or fzf select
gdl() {
  if [[ -n "$1" ]]; then
    git branch | grep -F "$1" | sed 's/^\*//' | xargs -n1 git branch -D
  else
    local branches
    branches=$(__git_fzf_local_branch 'delete branch> ' --multi)
    [[ -z "$branches" ]] && return 1
    echo "$branches" | xargs -n1 git branch -D --
  fi
}

# pull all git repos in current dir
gpla() {
  for dir in */; do
    [ -d "$dir/.git" ] || continue
    echo "=== Pulling $dir ==="
    git -C "$dir" pull --ff-only
  done
}

# worktrees
alias gwl='git worktree list'
alias gwp='git worktree prune'

__git_worktree_path() {
  local branch="$1" root="${2:-$(git rev-parse --show-toplevel)}"
  echo "${root:h}/${root:t}-worktrees/$branch"
}

__git_worktree_add() {
  local local_branch="$1" target="$2" start_point="$3"
  if git show-ref --verify --quiet "refs/heads/$local_branch"; then
    git worktree add "$target" "$local_branch"
  elif [[ -n "$start_point" ]]; then
    git worktree add -b "$local_branch" "$target" "$start_point"
  else
    git worktree add -b "$local_branch" "$target" "$(__git_default_branch)"
  fi
}

__git_worktree_for_branch() {
  git worktree list --porcelain | awk -v b="refs/heads/$1" '
    /^worktree / { path=$2 }
    /^branch / && $2==b { print path }
  '
}

## normalize remote branch: strips remote prefix into local_branch/start_point refs
## usage: __git_normalize_branch <branch> <local_branch_varname> <start_point_varname> [explicit_start]
__git_normalize_branch() {
  local _branch="$1" _explicit="${4:-}"
  typeset -n _lbref="$2" _spref="$3"
  if [[ -n "$_explicit" ]]; then
    _spref="$_explicit"
  else
    local _remote_prefix="${_branch%%/*}"
    if [[ "$_branch" == */* ]] && git remote | grep -qx "$_remote_prefix" \
        && ! git show-ref --verify --quiet "refs/heads/$_branch"; then
      _lbref="${_branch#*/}"
      _spref="$_branch"
    fi
  fi
}

## create or reuse worktree (fzf select or branch arg)
gwc() {
  local branch
  if [[ -n "$1" ]]; then
    branch="$1"
  else
    branch=$(__git_branch_list | __fzf --prompt='worktree branch> ')
  fi
  [[ -z "$branch" ]] && return 1

  local local_branch="$branch" start_point=""
  __git_normalize_branch "$branch" local_branch start_point

  local target="$(__git_worktree_path "$local_branch")"
  mkdir -p "$(dirname "$target")"
  __git_worktree_add "$local_branch" "$target" "$start_point" || return 1
  echo "Worktree at: $target"
}

## cd to worktree (fzf select or branch arg)
gws() {
  local selected="$(__git_resolve_worktree 'worktree> ' "$1")" || return
  cd "$selected" || return 1
}

## remove worktree (fzf select or branch arg)
gwd() {
  local selected="$(__git_resolve_worktree 'remove worktree> ' "$1")" || return
  [[ -n "$selected" ]] && git worktree remove "$selected"
}

## cd to main worktree
gwsm() {
  local main_wt
  main_wt=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
  [[ -n "$main_wt" ]] && { cd "$main_wt" || return 1; }
}

# completions
__git_complete_as() {
  words=(git $1 "${(@)words[2,-1]}")
  (( CURRENT += 1 ))
  local service=git
  _git
}

_complete_worktree_branches() {
  local branches
  branches=(${(f)"$(__git_worktree_branches)"})
  _describe 'worktree' branches
}

() {
  local -A _git_completions=(
    gsw switch  gswd switch  gdb diff
    gmb merge   gmbn merge   gmbs merge
    gwc switch
  )
  local fn cmd
  for fn cmd in "${(@kv)_git_completions}"; do
    eval "_${fn}() { __git_complete_as ${cmd} }; compdef _${fn} ${fn}"
  done
  local -a _wt_completions=(gdaw gdawh gwd gws)
  for fn in "${_wt_completions[@]}"; do
    eval "_${fn}() { _complete_worktree_branches }; compdef _${fn} ${fn}"
  done
}
