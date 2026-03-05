# helpers
__git_fzf_branch() {
  local cmd=$1 prompt=$2; shift 2
  if [[ -n "$1" ]]; then
    git ${=cmd} "$@"
  else
    local branch
    branch=$(__git_branch_list | fzf --prompt="$prompt" --height=40% --reverse)
    [[ -n "$branch" ]] && git ${=cmd} "$branch"
  fi
}

__git_stash_fzf() {
  local action=$1 prompt=$2; shift 2
  local entry
  entry=$(git stash list | fzf --prompt="$prompt" --height=40% --reverse)
  [[ -z "$entry" ]] && return 1
  git stash $action "$@" "${entry%%:*}"
}

__git_branch_list() {
  git branch --all --format='%(refname:short)' \
    | sed 's#^remotes/##' \
    | sort -u
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
    gmn    merge --no-edit (fzf)
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
    gdb    diff branch (fzf)
    gdm    git diff main
  resets
    grh    git reset --hard
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
  worktrees
    gwa    add worktree (fzf)
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

## stash pop/drop (fzf select)
gspf() { __git_stash_fzf pop  'pop stash> '  "$@"; }
gsdf() { __git_stash_fzf drop 'drop stash> ' "$@"; }

# commits
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'

# merging
alias gm='git merge'
alias gms='git merge --squash'
## merge (inline or fzf select)
gmn() { __git_fzf_branch  'merge --no-edit' 'merge> ' "$@"; }
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

## apply diff from worktree (fzf select)
gdaw() {
  local wt
  wt=$(git worktree list --porcelain | grep '^worktree ' | sed 's/^worktree //' \
    | fzf --prompt='apply from worktree> ' --height=40% --reverse)
  [[ -n "$wt" ]] || return
  git -C "$wt" diff | git apply && echo "Applied diff from $wt"
}

## diff branch (inline or fzf select)
gdb() { __git_fzf_branch diff 'diff branch> ' "$@"; }

## diff main/master (autodetect)
gdm() { git diff "$(__git_default_branch)"; }

# resets
alias grh='git reset --hard'
alias grs='git reset --soft'

# branches
alias gbr='git branch'
alias gco='git checkout'
alias gswc='git switch --create'

## switch branch (inline or fzf select)
gsw()  { __git_fzf_branch switch      'switch> ' "$@"; }
gswd() { __git_fzf_branch 'switch -d' 'detach> ' "$@"; }

## switch to main/master (autodetect)
gswm() {
  git switch "$(__git_default_branch)"
}

## swap branch with stash (fzf select)
gswap() {
  local branch
  branch=$(git branch --format='%(refname:short)' \
    | fzf --prompt='swap to> ' --height=40% --reverse)
  [[ -z "$branch" ]] && return 1
  git stash -m "switch staging" && git switch "$branch" && git stash pop
}

## delete branches by pattern, or fzf select
gdl() {
  if [ -n "$1" ]; then
    git branch | grep -E "$1" | sed 's/^\*//' | xargs -n1 git branch -D
  else
    local branches
    branches=$(git branch --format='%(refname:short)' \
      | fzf --multi --prompt='delete branch> ' --height=40% --reverse)
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

## add worktree for existing branch (fzf select)
gwa() {
  local branch
  branch=$(git branch --format='%(refname:short)' \
    | fzf --prompt='worktree branch> ' --height=40% --reverse)
  [[ -z "$branch" ]] && return 1
  local root
  root="$(git rev-parse --show-toplevel)"
  local base_dir
  base_dir="$(dirname "$root")/$(basename "$root")-worktrees"
  local target="$base_dir/$branch"
  mkdir -p "$(dirname "$target")"
  git worktree add "$@" "$target" "$branch"
  echo "Worktree at: $target"
}

## cd to worktree (fzf select)
gws() {
  local selected
  selected=$(git worktree list --porcelain \
    | grep '^worktree ' \
    | sed 's/^worktree //' \
    | fzf --prompt='worktree> ' --height=40% --reverse)
  [[ -n "$selected" ]] && cd "$selected"
}

## remove worktree (fzf select)
gwd() {
  local selected
  selected=$(git worktree list \
    | fzf --prompt='remove worktree> ' --height=40% --reverse \
    | awk '{print $1}')
  [[ -n "$selected" ]] && git worktree remove "$@" "$selected"
}

## cd to main worktree
gwsm() {
  local main_wt
  main_wt=$(git worktree list --porcelain | grep '^worktree ' | head -1 | sed 's/^worktree //')
  [[ -n "$main_wt" ]] && cd "$main_wt"
}

# completions
__git_complete_as() {
  words=(git $1 "${(@)words[2,-1]}")
  (( CURRENT += 1 ))
  local service=git
  _git
}

_gsw()  { __git_complete_as switch }
_gswd() { __git_complete_as switch }
_gdb()  { __git_complete_as diff   }
_gmb()  { __git_complete_as merge  }
_gmn()  { __git_complete_as merge  }
_gmbs() { __git_complete_as merge  }

compdef _gsw  gsw
compdef _gswd gswd
compdef _gdb  gdb
compdef _gmb  gmb
compdef _gmn  gmn
compdef _gmbs gmbs
