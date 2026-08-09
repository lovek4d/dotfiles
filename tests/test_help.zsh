#!/usr/bin/env zsh
# The help heredocs are the canonical alias reference (see CLAUDE.md). They are
# hand-written on purpose — the prose carries more than the names do — so this
# only checks that nothing defined has gone undocumented.
source "${0:A:h}/lib.zsh"

## every public alias/function defined in a file (leading _ means internal)
_defined_in() {
  awk '
    /^[[:space:]]*alias [a-z_]/     { n=$2; sub(/=.*/, "", n); print n; next }
    /^[a-z_][a-zA-Z0-9_-]*\(\)/     { n=$1; sub(/\(\).*/, "", n); print n; next }
  ' "$1" | grep -v '^_' | sort -u
}

## every name mentioned in any help heredoc, repo-wide — a name may be defined
## in one module and documented in another (cgt lives in agent-worktree, is
## documented under `c`)
_documented() {
  awk '
    /<<.?EOF/     { inside = 1; next }
    /^EOF$/       { inside = 0 }
    inside && /^[[:space:]][[:space:]]+[a-z]/ { print $1 }
  ' "$REPO_ROOT"/zshrc/*.zsh | sort -u
}

test_every_public_name_appears_in_a_help_block() {
  local documented="$(_documented)"
  local f name missing=()
  for f in "$REPO_ROOT"/zshrc/*.zsh; do
    for name in ${(f)"$(_defined_in $f)"}; do
      [[ $'\n'"$documented"$'\n' == *$'\n'"$name"$'\n'* ]] || missing+=("${f:t}: $name")
    done
  done
  (( ${#missing} == 0 )) || __fail "undocumented public names:" "${(F)missing}"
}

test_help_blocks_are_not_empty() {
  local f
  for f in "$REPO_ROOT"/zshrc/*.zsh; do
    grep -q "<<'EOF'" "$f" || continue
    (( $(_documented | wc -l) > 0 )) || __fail "${f:t}: help block extracted nothing"
  done
}

run_tests
