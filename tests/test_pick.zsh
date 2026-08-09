#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"

test_pick_prints_the_selection() {
  stub fzf feature
  load
  assert_eq feature "$(print -rl -- main feature | __pick 'p> ')"
}

test_pick_passes_prompt_and_fzf_args_through() {
  stub fzf a
  load
  print a | __pick 'choose> ' --multi >/dev/null
  assert_called "fzf --height=40% --reverse --no-sort --prompt=choose>  --multi"
}

test_pick_fails_on_empty_selection() {
  stub fzf ""
  load
  print a | __pick 'p> ' >/dev/null
  assert_err $?
}

test_pick_fails_when_fzf_is_cancelled() {
  stub fzf ""
  stub_rc fzf 130
  load
  print a | __pick 'p> ' >/dev/null
  assert_err $?
}

test_pick_keeps_multi_selections_newline_separated() {
  stub fzf $'one\ntwo'
  load
  assert_eq $'one\ntwo' "$(print a | __pick 'p> ' --multi)"
}

run_tests
