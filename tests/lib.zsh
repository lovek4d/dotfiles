#!/usr/bin/env zsh
# Assertions and command stubs for the zshrc modules.
#
# Every module invokes external tools as a bare command word — `git`, `tmux`,
# `fzf`. That word is the seam. `stub git` puts a recording adapter at it; the
# interactive shell gets the real binary. Modules need no changes to be tested.

typeset -g  REPO_ROOT="${0:A:h:h}"
typeset -gA STUB_OUT STUB_RC
typeset -gi FAILURES=0

# Calls are recorded to a file, not an array: modules routinely invoke each
# other through $(...), and a subshell's array writes are discarded.
typeset -g STUB_LOG="$(mktemp "${TMPDIR:-/tmp}/zshrc-stub.XXXXXX")"
trap 'rm -f "$STUB_LOG"' EXIT

# stubs

## stub <name> [stdout] — shadow a command, record its argv, replay stdout
stub() {
  local name="$1"; shift
  STUB_OUT[$name]="$*"
  functions[$name]='print -r -- "'$name' $*" >> "$STUB_LOG"
    [[ -n "${STUB_OUT['$name']}" ]] && print -r -- "${STUB_OUT['$name']}"
    return ${STUB_RC['$name']:-0}'
}

## stub_rc <name> <code> — make a stub exit non-zero
stub_rc() { STUB_RC[$1]=$2; }

## stub_fn <name> <body> — shadow a command with arbitrary zsh, still recorded
stub_fn() {
  local name="$1" body="$2"
  functions[$name]='print -r -- "'$name' $*" >> "$STUB_LOG"
    '"$body"
}

## calls — every recorded invocation, one per line
calls() { cat "$STUB_LOG"; }

# assertions

__fail() {
  (( FAILURES++ ))
  print -rl -- "$@"
}

assert_eq() {
  local expected="$1" actual="$2"
  [[ "$expected" == "$actual" ]] && return 0
  __fail "expected: $expected" "actual:   $actual"
}

## assert_called <substring> — a recorded invocation contains <substring>
assert_called() {
  [[ "$(calls)" == *"$1"* ]] && return 0
  __fail "expected a call matching: $1" "recorded:" "$(calls)"
}

assert_not_called() {
  [[ "$(calls)" != *"$1"* ]] && return 0
  __fail "expected NO call matching: $1" "recorded:" "$(calls)"
}

## assert_call_count <n> <substring>
assert_call_count() {
  local want="$1" pat="$2" n=0 line
  while IFS= read -r line; do [[ "$line" == *"$pat"* ]] && (( n++ )); done < "$STUB_LOG"
  (( n == want )) && return 0
  __fail "expected $want calls matching: $pat" "got: $n" "$(calls)"
}

assert_ok()  { (( $1 == 0 )) || __fail "expected success, got exit $1"; }
assert_err() { (( $1 != 0 )) || __fail "expected failure, got exit 0"; }

# module loading

## load <module...> — source zshrc modules with completion registration inert.
## Call after stubbing: modules with load-time side effects hit the stubs.
load() {
  functions[compdef]=':'
  source "$REPO_ROOT/zshrc/platform.zsh"
  source "$REPO_ROOT/zshrc/pick.zsh"
  local m
  for m in "$@"; do source "$REPO_ROOT/zshrc/$m.zsh" || return 1; done
}

# runner

__reset() { : > "$STUB_LOG"; FAILURES=0 }

## run every test_* function defined in the calling file
run_tests() {
  local fn out rc=0 status_ nl=$'\n'
  print -r -- "${ZSH_ARGZERO:t}"
  for fn in ${(ok)${(k)functions[(I)test_*]}}; do
    out="$( __reset; $fn 2>&1; (( FAILURES == 0 )) )"
    status_=$?
    if (( status_ == 0 )); then
      print -r -- "  ok   $fn"
    else
      print -r -- "  FAIL $fn"
      [[ -n "$out" ]] && print -r -- "      ${out//$nl/$nl      }"
      rc=1
    fi
  done
  return $rc
}
