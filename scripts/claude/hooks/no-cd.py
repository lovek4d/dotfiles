#!/usr/bin/env python3
import json, re, sys

data = json.load(sys.stdin)
cmd = data.get('tool_input', {}).get('command', '')

if re.search(r'(?:^|[;&|]|\n)\s*cd(\s|$)', cmd, re.MULTILINE):
    print(
        "Blocked: do not use `cd` — it has no effect on subsequent tool calls. "
        "Use relative paths for files within the project, or absolute paths for "
        "everything else. Rewrite the command without `cd`."
    )
    sys.exit(2)
