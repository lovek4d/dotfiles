#!/usr/bin/env bash
# Claude Code status line

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // empty' 2>/dev/null)
ctx=$(echo "$input" | jq -r 'if .context_window.used_percentage then "\(.context_window.used_percentage)% ctx" else empty end' 2>/dev/null)

# Full cwd for git; short display dir
cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
dir=""
if [[ -n "$cwd" ]]; then
    dir="${cwd/#$HOME/\~}"
    # Bash 3.2-compatible: use awk instead of negative array indices
    dir=$(echo "$dir" | awk -F/ '{if(NF>2) print $(NF-1)"/"$NF; else print $0}')
fi

# Git branch + dirty flag (run against full cwd)
branch=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)
    if [[ -n "$branch" ]]; then
        if ! git -C "$cwd" diff --quiet 2>/dev/null \
           || ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
            branch="${branch}*"
        fi
    fi
fi

# Assemble parts
out=""
[[ -n "$dir" ]]    && out="${out:+$out  }$dir"
[[ -n "$branch" ]] && out="${out:+$out  }$branch"
[[ -n "$model" ]]  && out="${out:+$out  }$model"
[[ -n "$ctx" ]]    && out="${out:+$out  }$ctx"

echo "$out"
