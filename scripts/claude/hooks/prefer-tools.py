#!/usr/bin/env python3
import json, re, sys

data = json.load(sys.stdin)
cmd = data.get('tool_input', {}).get('command', '')

# Check 1: Escaped shell operators that hide command structure
if re.search(r'\\[;|&<>]', cmd):
    print(
        "Blocked: escaped shell operators (\\; \\| \\& \\< \\>) hide command "
        "structure in the permission prompt. Use Read/Edit/Write tools or "
        "allowlisted helpers (rg, fd), or restructure the command to avoid "
        "backslash-escaped operators.",
        file=sys.stderr,
    )
    sys.exit(2)

# Check 2: Shell loops iterating over file globs
if re.search(r'\bfor\s+\w+\s+in\s+[^;]*(?:\*\*|\*)', cmd):
    print(
        "Blocked: shell loops over file globs should use built-in tools. "
        "Use `fd` to find matching files, then `rg` or the Read tool to process "
        "their contents.",
        file=sys.stderr,
    )
    sys.exit(2)

# Check 3: find → use fd
if re.match(r'\s*find\b', cmd):
    print(
        "Blocked: use `fd` instead of `find` for file discovery. "
        "fd is allowlisted, has saner default syntax, and respects .gitignore.",
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

# Check 5: grep → use rg
if re.match(r'\s*grep\b', cmd):
    print(
        "Blocked: use `rg` instead of `grep` for searching file contents. "
        "rg is allowlisted, faster, and supports the same regex/glob/context flags.",
        file=sys.stderr,
    )
    sys.exit(2)
