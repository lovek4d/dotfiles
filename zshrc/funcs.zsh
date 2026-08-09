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
  local selection pids
  selection=$(ps aux | __pick 'kill> ' --multi --header-lines=1) || return 0
  pids=$(echo "$selection" | awk '{print $2}')
  kill -"$sig" ${(f)pids}
  echo "sent SIG$sig to: ${(f)pids}"
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

# rerun a python file on change, clearing the screen each time
py_watch() {
  [[ -z "$1" ]] && echo "usage: py_watch <file.py>" && return 1
  echo "$1" | entr -cc python3 "$1"
}

# delayed enter — sleep N minutes then press Enter, keeping the machine awake
denter() {
  [[ -z "$1" ]] && echo "usage: denter <minutes>" && return 1
  local secs=$(( $1 * 60 ))
  local awake_pid; awake_pid="$(__keep_awake "$secs")"
  while (( secs > 0 )); do
    printf "\rdenter in %d:%02d " $(( secs / 60 )) $(( secs % 60 ))
    sleep 1
    (( secs-- ))
  done
  printf "\rdenter now!          \n"
  [[ -n "$awake_pid" ]] && kill "$awake_pid" 2>/dev/null
  __press_enter
}
