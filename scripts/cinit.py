#!/usr/bin/env python3
import json, os

path = os.path.expanduser("~/.claude/settings.json")
settings = {}
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)

Q = 'D=$HOME/.claude/queue; mkdir -p "$D"; S=$(tmux display-message -p "#{session_name}" 2>/dev/null) || exit 0'

def enqueue(typ, notify=True):
    bell = 'printf "\\a"; tmux display-message "Claude %s: $S" 2>/dev/null' % typ if notify else ':'
    return f"bash -c '{Q}; echo {typ} > \"$D/$S\"; {bell}'"

dequeue = f"bash -c '{Q}; rm -f \"$D/$S\"'"
to_thinking = f"bash -c '{Q}; f=\"$D/$S\"; if [ -f \"$f\" ] && read t < \"$f\" && [ \"$t\" = prompt ]; then echo thinking > \"$f\"; fi'"

settings["hooks"] = {
    "Notification": [
        {"matcher": "permission_prompt|elicitation_dialog",
         "hooks": [{"type": "command", "command": enqueue("prompt"), "timeout": 5}]},
        {"matcher": "idle_prompt",
         "hooks": [{"type": "command", "command": enqueue("idle"), "timeout": 5}]},
    ],
    "Stop":            [{"hooks": [{"type": "command", "command": enqueue("idle"),             "timeout": 5}]}],
    "PostToolUse":     [{"hooks": [{"type": "command", "command": to_thinking,                 "timeout": 5}]}],
    "UserPromptSubmit":[{"hooks": [{"type": "command", "command": enqueue("thinking", False),  "timeout": 5}]}],
    "SessionEnd":      [{"hooks": [{"type": "command", "command": dequeue,                     "timeout": 5}]}],
}

git_perms = [
    "Bash(git diff:*)",
    "Bash(git log:*)",
    "Bash(git status:*)",
    "Bash(git show:*)",
    "Bash(git branch:*)",
    "Bash(git remote:*)",
    "Bash(git rev-parse:*)",
]
perms = settings.setdefault("permissions", {})
allow = perms.setdefault("allow", [])
for p in git_perms:
    if p not in allow:
        allow.append(p)

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
