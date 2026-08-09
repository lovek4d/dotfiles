#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"

test_stub_records_argv() {
  stub git
  git switch main
  assert_called "git switch main"
  assert_not_called "git merge"
}

test_stub_replays_stdout() {
  stub git $'main\nfeature'
  assert_eq $'main\nfeature' "$(git branch)"
}

test_stub_rc() {
  stub git
  stub_rc git 3
  git status
  assert_eq 3 $?
}

test_stub_fn_still_records() {
  stub_fn tmux 'print -r -- "session-$1"'
  assert_eq "session-list" "$(tmux list)"
  assert_called "tmux list"
}

test_assert_call_count() {
  stub git
  git a; git b; git a
  assert_call_count 2 "git a"
  assert_call_count 1 "git b"
}

run_tests
