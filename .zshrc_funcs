# redact jsons quickly from clipboard
redact-json() {
    export CLIP=$(pbpaste)
    [[ -z "$CLIP" ]] && echo "Clipboard empty" && return 1
    
    python3 << 'EOF' | pbcopy && echo "Redacted JSON copied to clipboard"
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
