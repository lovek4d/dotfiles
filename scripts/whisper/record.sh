#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
shopt -s expand_aliases
source "$HOME/dev/dotfiles/zshrc/platform.zsh"

TMPRAW="/tmp/whisper-rec-raw.wav"
TMPFILE="/tmp/whisper-rec.wav"
TMPCHUNK="/tmp/whisper-chunk-raw.wav"
TMPCHUNK16="/tmp/whisper-chunk-16k.wav"
MODEL="$HOME/.whisper/models/ggml-large-v3-turbo.bin"
PROMPT="Software engineering discussion."

trap 'kill -INT $REC_PID $POLL_PID 2>/dev/null; wait $REC_PID $POLL_PID 2>/dev/null; rm -f "$TMPRAW" "$TMPFILE" "$TMPCHUNK" "$TMPCHUNK16"' EXIT

echo "[Whisper] Enter > C/P | ESC > copy | ^C > quit"
echo ""

rec -q -c 1 "$TMPRAW" &
REC_PID=$!

# Periodic preview: snapshot + transcribe every 5s
(
  while kill -0 $REC_PID 2>/dev/null; do
    sleep 5
    kill -0 $REC_PID 2>/dev/null || break
    cp "$TMPRAW" "$TMPCHUNK" 2>/dev/null
    sox --ignore-length "$TMPCHUNK" -r 16000 -b 16 -e signed-integer "$TMPCHUNK16" 2>/dev/null || continue
    preview=$(whisper-cli -m "$MODEL" -f "$TMPCHUNK16" --no-timestamps -l en --prompt "$PROMPT" 2>/dev/null \
      | grep -v '\[BLANK_AUDIO\]' | grep -v '^[[:space:]]*$' \
      | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -n "$preview" ]]; then
      tput cup 2 0
      tput ed
      printf '%s' "$preview"
    fi
  done
) &
POLL_PID=$!

read -r -s -n 1 key

# Drain trailing escape sequence bytes
if [[ "$key" == $'\e' ]]; then
  read -r -s -n 5 -t 0.05 _ 2>/dev/null || true
fi

kill -INT "$REC_PID" 2>/dev/null
wait "$REC_PID" 2>/dev/null
kill "$POLL_PID" 2>/dev/null
wait "$POLL_PID" 2>/dev/null
tput cup 2 0; tput ed

echo "Transcribing..."
sox "$TMPRAW" -r 16000 -b 16 -e signed-integer "$TMPFILE" 2>/dev/null
rm -f "$TMPRAW"

result=$(whisper-cli -m "$MODEL" -f "$TMPFILE" --no-timestamps -l en --prompt "$PROMPT" 2>/dev/null \
  | grep -v '\[BLANK_AUDIO\]' | grep -v '^[[:space:]]*$' \
  | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [[ -z "$result" ]]; then
  echo "No speech detected."
  exit 0
fi

echo "$result"
echo ""

case "$key" in
  "")
    # Enter: paste + copy
    printf '%s' "$result" | clipcopy
    tmux set-buffer "$result" && tmux paste-buffer 2>/dev/null
    ;;
  $'\e')
    # Escape: copy only
    printf '%s' "$result" | clipcopy
    echo "Copied to clipboard."
    ;;
esac
# Ctrl+C: EXIT trap fires, nothing pasted/copied
