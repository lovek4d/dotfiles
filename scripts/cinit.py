#!/usr/bin/env python3
"""Point ~/.claude at this repo: settings, hooks, statusline, agent skills.

The permission allowlist is data, not code — it lives in
configs/claude-permissions.json.
"""
import json, os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir))


def link_config(src, dest):
    """Symlink a repo file into place, replacing an existing link.

    Refuses to clobber a real file. Mirrors __link_config in zshrc/platform.zsh.
    """
    if not os.path.exists(src):
        raise SystemExit(f"link: missing source {src}")
    if os.path.exists(dest) and not os.path.islink(dest):
        raise SystemExit(f"link: {dest} exists and is not a symlink — leaving it alone")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.lexists(dest):
        os.remove(dest)
    os.symlink(src, dest)
    print(f"symlinked {dest} -> {src}")
    return dest


def merge_unique(target, additions):
    for item in additions:
        if item not in target:
            target.append(item)


settings_path = os.path.expanduser("~/.claude/settings.json")
settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)

hook = link_config(os.path.join(REPO, "scripts/claude/hooks/no-paths.py"),
                   os.path.expanduser("~/.claude/hooks/no-paths.py"))
statusline = link_config(os.path.join(REPO, "scripts/claude/statusline.sh"),
                         os.path.expanduser("~/.claude/statusline.sh"))

settings["statusLine"] = {"type": "command", "command": statusline}
settings["hooks"] = {
    "PreToolUse": [
        {"matcher": "Bash",
         "hooks": [{"type": "command", "command": f"python3 {hook}", "timeout": 5}]}
    ],
}
settings["showClearContextOnPlanAccept"] = True

with open(os.path.join(REPO, "configs/claude-permissions.json")) as f:
    configured = json.load(f)

perms = settings.setdefault("permissions", {})
merge_unique(perms.setdefault("allow", []), configured["allow"])
merge_unique(perms.setdefault("deny", []), configured["deny"])

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
print(f"updated {settings_path} "
      f"({len(configured['allow'])} allow, {len(configured['deny'])} deny, no-paths hook)")

# repo-authored skills -> every agent's skills dir; adding a skill needs no edit here
skills_src = os.path.join(REPO, "configs/agents/skills")
skills = sorted(d for d in os.listdir(skills_src)
                if os.path.isdir(os.path.join(skills_src, d))) if os.path.isdir(skills_src) else []

for agent_skills in ("~/.claude/skills", "~/.codex/skills"):
    dst_dir = os.path.expanduser(agent_skills)
    os.makedirs(dst_dir, exist_ok=True)
    # drop links into our skills dir whose source is gone; leave npx-managed ones alone
    for entry in os.listdir(dst_dir):
        dst = os.path.join(dst_dir, entry)
        if (os.path.islink(dst) and entry not in skills
                and os.path.realpath(dst).startswith(skills_src + os.sep)):
            os.remove(dst)
    for name in skills:
        link_config(os.path.join(skills_src, name), os.path.join(dst_dir, name))
