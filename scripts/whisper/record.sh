#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
source "$HOME/dev/dotfiles/zshrc/platform.zsh"

TMPRAW="/tmp/whisper-rec-raw.wav"
TMPFILE="/tmp/whisper-rec.wav"
MODEL="$HOME/.whisper/models/ggml-large-v3-turbo.bin"
PROMPT="Software engineering discussion."

trap 'kill -INT $REC_PID 2>/dev/null; rm -f "$TMPRAW" "$TMPFILE"' EXIT

echo "Recording... [Enter] to stop"
rec -q -c 1 "$TMPRAW" &
REC_PID=$!

read -r

kill -INT "$REC_PID"
wait "$REC_PID" 2>/dev/null

echo "Transcribing..."
sox "$TMPRAW" -r 16000 -b 16 -e signed-integer "$TMPFILE"
rm -f "$TMPRAW"
result=$(whisper-cli -m "$MODEL" -f "$TMPFILE" --no-timestamps -l en --prompt "$PROMPT" 2>/dev/null \
  | grep -v '^[[:space:]]*$' | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
rm -f "$TMPFILE"

if [[ -n "$result" ]]; then
  printf '%s' "$result" | pbcopy
  [[ -n "$TMUX" ]] && tmux set-buffer "$result" && tmux paste-buffer
  __notify "$result" "Whisper"
  echo "$result"
else
  echo "No speech detected"
fi
