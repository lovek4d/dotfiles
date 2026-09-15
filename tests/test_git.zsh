#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"

# A git that answers the queries the module asks, and records everything else.
fake_git() {
  stub_fn git '
    case "$*" in
      "rev-parse --path-format=absolute --git-common-dir") print -r -- /home/dev/repo/.git ;;
      "branch --format=%(refname:short)")                  print -rl -- feature main ;;
      "branch --remotes --format=%(refname:short)")        print -rl -- origin/main origin/hotfix ;;
      "symbolic-ref --short refs/remotes/origin/HEAD")     print -r -- origin/main ;;
      "remote")                                            print -r -- origin ;;
      "stash list")                                        print -rl -- "stash@{0}: WIP one" "stash@{1}: WIP two" ;;
      "worktree list --porcelain")
        print -rl -- "worktree /home/dev/repo" "branch refs/heads/main" \
                     "worktree /home/dev/repo-worktrees/feature" "branch refs/heads/feature" ;;
      "rev-parse --show-toplevel")                         print -r -- /home/dev/repo ;;
      "-C /home/dev/repo-worktrees/feature diff --quiet HEAD") return 1 ;;
      "-C /home/dev/repo-worktrees/feature diff --binary HEAD") print -r -- PATCH ;;
      "show-ref --verify --quiet refs/heads/feature") return 0 ;;
      show-ref*) return 1 ;;
      fetch*) return 1 ;;
    esac
    return 0'
}

# passthrough vs picker

test_gsw_with_arg_skips_the_picker() {
  fake_git; stub fzf
  load git
  gsw feature
  assert_called "git switch feature"
  assert_not_called "fzf"
}

test_gsw_without_arg_picks_a_branch() {
  fake_git; stub fzf feature
  load git
  gsw
  assert_called "fzf --height=40% --reverse --no-sort --prompt=switch> "
  assert_called "git switch feature"
}

test_gsw_cancelled_runs_no_git_command() {
  fake_git; stub fzf ""
  load git
  gsw
  assert_not_called "git switch"
}

test_gsw_remote_branch_tracks_into_a_local_branch() {
  fake_git; stub fzf
  load git
  gsw origin/hotfix
  assert_called "git switch -c hotfix origin/hotfix"
  assert_not_called "fzf"
}

test_branch_list_hides_remotes_that_have_a_local() {
  fake_git
  load git
  assert_eq $'feature\nmain\norigin/hotfix' "$(__git_branch_list)"
}

test_stash_pop_picker_uses_the_stash_ref() {
  fake_git; stub fzf "stash@{1}: WIP two"
  load git
  gspf
  assert_called "git stash pop stash@{1}"
}

# default branch

test_default_branch_from_origin_head() {
  fake_git
  load git
  assert_eq main "$(__git_default_branch)"
}

test_gdm_diffs_against_the_default_branch() {
  fake_git
  load git
  gdm
  assert_called "git diff main"
}

# worktrees

test_worktree_path_sits_beside_the_repo() {
  fake_git
  load git
  assert_eq "/home/dev/repo-worktrees/feature" "$(__git_worktree_path feature /home/dev/repo)"
}

test_branch_slug_flattens_slashes() {
  fake_git
  load git
  assert_eq "feat-a-b" "$(__git_branch_slug feat/a/b)"
}

test_resolve_worktree_finds_the_path_for_a_branch() {
  fake_git
  load git
  assert_eq "/home/dev/repo-worktrees/feature" "$(__git_resolve_worktree 'p> ' feature)"
}

test_resolve_worktree_errors_when_no_worktree() {
  fake_git
  load git
  local out; out="$(__git_resolve_worktree 'p> ' nope 2>&1)"
  assert_err $?
  assert_eq "no worktree for branch: nope" "$out"
}

test_gwaf_without_arg_picks_a_worktree_branch() {
  fake_git; stub fzf feature
  load git
  gwaf >/dev/null
  assert_called "fzf --height=40% --reverse --no-sort --prompt=apply from worktree (full)> "
  assert_called "git switch -d feature"
}

test_gwaf_cleans_before_detaching_and_applying() {
  fake_git; stub fzf
  load git
  local out; out="$(gwaf feature)"
  assert_ok $?
  assert_eq "Applied all changes from feature worktree" "$out"
  assert_eq $'git reset --hard\ngit -C /home/dev/repo clean -fd\ngit switch -d feature' \
    "$(calls | grep -E 'reset|clean|switch')"
  assert_called "git -C /home/dev/repo-worktrees/feature diff --binary HEAD"
  assert_called "git -C /home/dev/repo apply"
  assert_called "git -C /home/dev/repo-worktrees/feature ls-files --others --exclude-standard"
}

test_gwaf_stops_when_switch_fails() {
  fake_git; stub fzf
  load git
  functions[__real_git]=$functions[git]
  git() { [[ "$1" == switch ]] && return 1; __real_git "$@"; }
  gwaf feature >/dev/null 2>&1
  assert_err $?
  assert_not_called "diff --binary"
}

test_gwaf_cancelled_runs_no_git_command() {
  fake_git; stub fzf ""
  load git
  gwaf
  assert_not_called "git reset"
  assert_not_called "git switch"
}

test_apply_worktree_diff_skips_patch_when_worktree_diff_is_empty() {
  fake_git; stub fzf
  load git
  __git_apply_worktree_diff /home/dev/repo-worktrees/other
  assert_ok $?
  assert_not_called "apply"
}

test_gwc_reuses_an_existing_worktree() {
  fake_git; stub fzf
  load git
  local out; out="$(gwc feature)"
  assert_eq "Worktree at: /home/dev/repo-worktrees/feature" "$out"
  assert_not_called "git worktree add"
}

test_gwc_creates_a_worktree_for_a_new_branch() {
  fake_git; stub fzf; stub mkdir
  load git
  gwc newthing >/dev/null
  assert_called "git worktree add -b newthing /home/dev/repo-worktrees/newthing main"
}

test_gwc_normalizes_a_remote_branch() {
  fake_git; stub fzf; stub mkdir
  load git
  gwc origin/hotfix >/dev/null
  assert_called "git worktree add -b hotfix /home/dev/repo-worktrees/hotfix origin/hotfix"
}

# branch deletion

test_gdl_by_pattern_deletes_matches() {
  stub_fn git '
    case "$*" in "branch --format=%(refname:short)") print -rl -- feat-one main feat-two ;; esac
    return 0'
  load git
  gdl feat
  assert_called "git branch -d -- feat-one"
  assert_called "git branch -d -- feat-two"
  assert_not_called "-- main"
}

run_tests
