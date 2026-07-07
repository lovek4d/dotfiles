#!/usr/bin/env python3
import json, os

path = os.path.expanduser("~/.claude/settings.json")
settings = {}
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)

hooks_dir = os.path.expanduser("~/.claude/hooks")
os.makedirs(hooks_dir, exist_ok=True)
hook_src = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "claude/hooks/no-paths.py"))
hook_dst = os.path.join(hooks_dir, "no-paths.py")
if os.path.lexists(hook_dst):
    os.remove(hook_dst)
os.symlink(hook_src, hook_dst)
no_paths_hook = f"python3 {hook_dst}"

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
         ]}
    ],
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
    "Bash(bat:*)",
    "Bash(ls:*)",
    "Bash(find:*)",
    "Bash(fd:*)",
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
    "Bash(tldr:*)",
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
