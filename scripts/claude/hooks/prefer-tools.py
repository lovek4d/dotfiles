#!/usr/bin/env python3
import json, re, sys

data = json.load(sys.stdin)
cmd = data.get('tool_input', {}).get('command', '')

# Check 1: Escaped shell operators that hide command structure
if re.search(r'\\[;|&<>]', cmd):
    print(
        "Blocked: escaped shell operators (\\; \\| \\& \\< \\>) hide command "
        "structure in the permission prompt. Use Glob/Grep/Read tools instead, "
        "or restructure the command to avoid backslash-escaped operators.",
        file=sys.stderr,
    )
    sys.exit(2)

# Check 2: Shell loops iterating over file globs
if re.search(r'\bfor\s+\w+\s+in\s+[^;]*(?:\*\*|\*)', cmd):
    print(
        "Blocked: shell loops over file globs should use built-in tools. "
        "Use Glob to find matching files, then Grep or Read to process "
        "their contents.",
        file=sys.stderr,
    )
    sys.exit(2)

# Check 3: find → use Glob
if re.match(r'\s*find\b', cmd):
    print(
        "Blocked: use the Glob tool instead of `find` for file discovery. "
        "Glob supports patterns like '**/*.swift' and returns sorted results.",
        file=sys.stderr,
    )
    sys.exit(2)

# Check 4: cat/head/tail → use Read
if re.match(r'\s*(cat|head|tail)\b', cmd) and not re.match(r'\s*tail\s+(-f|--follow)\b', cmd):
    print(
        "Blocked: use the Read tool instead of cat/head/tail for reading files. "
        "Read supports offset and limit parameters for partial reads.",
        file=sys.stderr,
    )
    sys.exit(2)

# Check 5: grep/rg → use Grep
if re.match(r'\s*(grep|rg)\b', cmd):
    print(
        "Blocked: use the Grep tool instead of grep/rg for searching file "
        "contents. Grep supports regex, glob filters, context lines, and "
        "multiple output modes.",
        file=sys.stderr,
    )
    sys.exit(2)
