#!/usr/bin/env zsh
# Run every tests/test_*.zsh in its own zsh process.
# usage: tests/run.zsh [name-filter]

cd "${0:A:h:h}" || exit 1

local -a files
files=(tests/test_*.zsh)
[[ -n "$1" ]] && files=(tests/test_*"$1"*.zsh(N))

if (( ${#files} == 0 )); then
  print -u2 "no test files match: ${1:-*}"
  exit 1
fi

local f rc=0
for f in $files; do
  zsh "$f" || rc=1
done

print
if (( rc == 0 )); then
  print -r -- "all passed (${#files} files)"
else
  print -r -- "FAILURES"
fi
exit $rc
