# redact jsons quickly from clipboard
redact-json() {
    local _clip
    _clip=$(clippaste)
    [[ -z "$_clip" ]] && echo "Clipboard empty" && return 1
    CLIP="$_clip" python3 << 'EOF' | clipcopy && echo "Redacted JSON copied to clipboard"
import os
import json
import re

raw = os.environ.get("CLIP", "")
raw = re.sub(r"[\x00-\x1f]", " ", raw)

def redact(obj):
    if isinstance(obj, dict):
        return {k: redact(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact(i) for i in obj]
    return "[REDACTED]"

data = json.loads(raw)
print(json.dumps(redact(data), indent=2))
EOF
}

# fzf multi-select process killer
pk() {
  local sig="${1:-TERM}"
  local pids
  pids=$(ps aux | __fzf --multi --header-lines=1 | awk '{print $2}')
  [[ -z "$pids" ]] && return 0
  echo "$pids" | xargs kill -"$sig"
  echo "sent SIG$sig to: $(echo $pids | tr '\n' ' ')"
}

# show what's on a port, prompt to kill
port() {
  [[ -z "$1" ]] && echo "usage: port <number>" && return 1
  local output
  output=$(lsof -i :"$1" -sTCP:LISTEN 2>/dev/null)
  if [[ -z "$output" ]]; then
    echo "nothing on port $1"
    return 0
  fi
  echo "$output"
  local pid
  pid=$(awk 'NR==2 {print $2; exit}' <<< "$output")
  [[ -z "$pid" ]] && return 0
  echo ""
  read -q "reply?kill pid $pid? [y/N] " || { echo; return 0; }
  echo
  kill "$pid" && echo "killed $pid"
}
