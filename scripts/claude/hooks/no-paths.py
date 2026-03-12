#!/usr/bin/env python3
import json, os, re, sys

data = json.load(sys.stdin)
cmd = data.get('tool_input', {}).get('command', '')

if re.search(r'(?:^|[;&|]|\n)\s*cd(\s|$)', cmd, re.MULTILINE):
    print(
        "Blocked: do not use `cd` — it has no effect on subsequent tool calls. "
        "Use relative paths for files within the project, or absolute paths for "
        "everything else. Rewrite the command without `cd`."
    )
    sys.exit(2)

cwd = os.path.realpath(os.getcwd())
for m in re.finditer(r'\bgit\b[^;&|\n]*\s-C\s+([^\s;&|\n]+)', cmd):
    if os.path.realpath(m.group(1)) == cwd:
        print(
            "Blocked: do not use `git -C <path>` when <path> is the current working "
            "directory — it bypasses allowlisted permission patterns. "
            "Use bare `git` commands instead."
        )
        sys.exit(2)
