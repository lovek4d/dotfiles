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

hooks_dir = os.path.expanduser("~/.claude/hooks")
os.makedirs(hooks_dir, exist_ok=True)
hook_src = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "claude/hooks/no-paths.py"))
hook_dst = os.path.join(hooks_dir, "no-paths.py")
if os.path.lexists(hook_dst):
    os.remove(hook_dst)
os.symlink(hook_src, hook_dst)
no_paths_hook = f"python3 {hook_dst}"

prefer_tools_src = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "claude/hooks/prefer-tools.py"))
prefer_tools_dst = os.path.join(hooks_dir, "prefer-tools.py")
if os.path.lexists(prefer_tools_dst):
    os.remove(prefer_tools_dst)
os.symlink(prefer_tools_src, prefer_tools_dst)
prefer_tools_hook = f"python3 {prefer_tools_dst}"

statusline_src = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "claude/statusline.sh"))
statusline_dst = os.path.expanduser("~/.claude/statusline.sh")
if os.path.lexists(statusline_dst):
    os.remove(statusline_dst)
os.symlink(statusline_src, statusline_dst)

settings["statusLine"] = {"type": "command", "command": statusline_dst}

settings["hooks"] = {
    "PreToolUse": [
        {"matcher": "Bash",
         "hooks": [
             {"type": "command", "command": no_paths_hook, "timeout": 5},
             {"type": "command", "command": prefer_tools_hook, "timeout": 5},
         ]}
    ],
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

readonly_perms = [
    # version control — git
    "Bash(git diff:*)",
    "Bash(git log:*)",
    "Bash(git status:*)",
    "Bash(git show:*)",
    "Bash(git branch:*)",
    "Bash(git remote:*)",
    "Bash(git rev-parse:*)",
    "Bash(git grep:*)",
    "Bash(git ls-tree:*)",
    # version control — github cli
    "Bash(gh pr view:*)",
    "Bash(gh pr list:*)",
    "Bash(gh pr checks:*)",
    "Bash(gh pr diff:*)",
    "Bash(gh pr status:*)",
    "Bash(gh issue view:*)",
    "Bash(gh issue list:*)",
    "Bash(gh run view:*)",
    "Bash(gh run list:*)",
    "Bash(gh repo view:*)",
    "Bash(gh release view:*)",
    "Bash(gh release list:*)",
    "Bash(gh auth status:*)",
    "Bash(gh search:*)",
    "Bash(gh status:*)",
    # file inspection
    "Bash(cat:*)",
    "Bash(head:*)",
    "Bash(tail:*)",
    "Bash(ls:*)",
    "Bash(find:*)",
    "Bash(file:*)",
    "Bash(stat:*)",
    "Bash(readlink:*)",
    "Bash(realpath:*)",
    "Bash(basename:*)",
    "Bash(dirname:*)",
    # text processing
    "Bash(grep:*)",
    "Bash(rg:*)",
    "Bash(jq:*)",
    "Bash(sed:*)",
    "Bash(awk:*)",
    "Bash(sort:*)",
    "Bash(uniq:*)",
    "Bash(cut:*)",
    "Bash(tr:*)",
    "Bash(diff:*)",
    "Bash(wc:*)",
    # system info
    "Bash(env:*)",
    "Bash(printenv:*)",
    "Bash(pwd:*)",
    "Bash(ps:*)",
    "Bash(du:*)",
    "Bash(df:*)",
    "Bash(date:*)",
    "Bash(uname:*)",
    "Bash(whoami:*)",
    "Bash(id:*)",
    "Bash(hostname:*)",
    "Bash(which:*)",
    "Bash(type:*)",
    # shell builtins
    "Bash(echo:*)",
    "Bash(test:*)",
    # web browsing
    "WebFetch(*)",
    "WebSearch(*)",
]
denied_perms = [
    "Bash(sed -i:*)",
    "Bash(sed --in-place:*)",
]

perms = settings.setdefault("permissions", {})
allow = perms.setdefault("allow", [])
for p in readonly_perms:
    if p not in allow:
        allow.append(p)
deny = perms.setdefault("deny", [])
for p in denied_perms:
    if p not in deny:
        deny.append(p)

settings["showClearContextOnPlanAccept"] = True

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
