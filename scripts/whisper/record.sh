#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
shopt -s expand_aliases
source "$HOME/dev/dotfiles/zshrc/platform.zsh"

case "${1:-}" in
  -h|--help) echo "usage: record.sh"; exit 0 ;;
  "") ;;
  *) echo "usage: record.sh" >&2; exit 1 ;;
esac

RUN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/whisper.XXXXXX") || exit 1
TMPRAW="$RUN_DIR/whisper-rec-raw.wav"
TMPFILE="$RUN_DIR/whisper-rec.wav"
TMPCHUNK="$RUN_DIR/whisper-chunk-raw.wav"
TMPCHUNK16="$RUN_DIR/whisper-chunk-16k.wav"
MODEL="${WHISPER_MODEL:-$HOME/.whisper/models/ggml-large-v3-turbo.bin}"
PROMPT="${WHISPER_PROMPT:-Engineering discussion, some general use.}"
CLOSER_WORD="${WHISPER_CLOSER_WORD:-send it}"
CLOSER_FLAG="$RUN_DIR/closer-flag"
CLOSER_RESULT="$RUN_DIR/closer-result"

draw_preview() {
  local preview="$1"
  local cols width
  cols=$(tput cols 2>/dev/null || echo 80)
  width=$(( cols > 2 ? cols - 2 : 80 ))

  tput clear 2>/dev/null || printf '\n'
  if [[ -n "$TMUX" ]]; then
    echo "[Whisper] Enter > paste | ESC > copy | '$CLOSER_WORD' > submit | ^C > quit"
  else
    echo "[Whisper] Enter/ESC/'$CLOSER_WORD' > copy | ^C > quit"
  fi
  echo "[Whisper] live preview:"
  echo ""
  printf '%s' "$preview" | fold -s -w "$width"
}

transcribe_file() {
  local file="$1" joiner="${2- }"
  whisper-cli -m "$MODEL" -f "$file" --no-timestamps -l en --prompt "$PROMPT" 2>/dev/null \
    | grep -v '\[BLANK_AUDIO\]' | grep -v '^[[:space:]]*$' \
    | { if [[ -z "$joiner" ]]; then tr -d '\n\r'; else tr '\n\r' "$joiner"; fi; } \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

has_closer_word() {
  echo "$1" | grep -qiE "(^|[[:space:]])${CLOSER_WORD}([[:punct:]]*([[:space:]]|$))"
}

strip_closer_word() {
  printf '%s' "$1" \
    | sed -E "s/(^|[[:space:]])${CLOSER_WORD}[[:punct:]]*([[:space:]]|$)/\1\2/gI" \
    | sed -E 's/[[:space:]]+/ /g;s/^[[:space:]]*//;s/[[:space:]]*$//'
}

deliver_result() {
  local mode="$1" result="$2"
  printf '%s' "$result" | clipcopy
  case "$mode" in
    submit)
      if [[ -n "$TMUX" ]]; then
        tmux send-keys -l -- "$result" 2>/dev/null && tmux send-keys Enter 2>/dev/null
      else
        echo "Copied to clipboard."
      fi
      ;;
    paste)
      if [[ -n "$TMUX" ]]; then
        tmux send-keys -l -- "$result" 2>/dev/null
      else
        echo "Copied to clipboard."
      fi
      ;;
    copy)
      echo "Copied to clipboard."
      ;;
  esac
}

cleanup() {
  [[ -n "${REC_PID:-}" ]] && kill -INT "$REC_PID" 2>/dev/null
  [[ -n "${POLL_PID:-}" ]] && kill "$POLL_PID" 2>/dev/null
  [[ -n "${REC_PID:-}${POLL_PID:-}" ]] && wait ${REC_PID:-} ${POLL_PID:-} 2>/dev/null
  rm -rf "$RUN_DIR"
}
trap cleanup EXIT

draw_preview ""

rec -q "$TMPRAW" &
REC_PID=$!

# Periodic preview: snapshot + transcribe every 5s
(
  while kill -0 $REC_PID 2>/dev/null; do
    sleep 5
    kill -0 $REC_PID 2>/dev/null || break
    cp "$TMPRAW" "$TMPCHUNK" 2>/dev/null
    sox --ignore-length "$TMPCHUNK" -r 16000 -b 16 -c 1 -e signed-integer "$TMPCHUNK16" 2>/dev/null || continue
    preview=$(transcribe_file "$TMPCHUNK16" "")
    if [[ -n "$preview" ]]; then
      draw_preview "$preview"
      if has_closer_word "$preview"; then
        strip_closer_word "$preview" > "$CLOSER_RESULT"
        touch "$CLOSER_FLAG"
        kill -INT "$REC_PID" 2>/dev/null
        break
      fi
    fi
  done
) &
POLL_PID=$!

key=""
closer_triggered=false
while true; do
  read -r -s -n 1 -t 1 key
  if [[ $? -eq 0 ]]; then
    break
  fi
  if [[ -f "$CLOSER_FLAG" ]]; then
    closer_triggered=true
    break
  fi
done

# Drain trailing escape sequence bytes
if [[ "$key" == $'\e' ]]; then
  read -r -s -n 5 -t 0.05 _ 2>/dev/null || true
fi

kill -INT "$REC_PID" 2>/dev/null
wait "$REC_PID" 2>/dev/null
kill "$POLL_PID" 2>/dev/null
wait "$POLL_PID" 2>/dev/null
tput clear 2>/dev/null || printf '\n'

if [[ "$closer_triggered" == true ]]; then
  result=$(cat "$CLOSER_RESULT" 2>/dev/null)
  if [[ -z "$result" ]]; then
    echo "No speech detected."
    exit 0
  fi
  echo "$result"
  echo ""
  [[ -n "$TMUX" ]] && deliver_result submit "$result" || deliver_result copy "$result"
  exit 0
fi

echo "Transcribing..."
sox "$TMPRAW" -r 16000 -b 16 -c 1 -e signed-integer "$TMPFILE" 2>/dev/null
rm -f "$TMPRAW"

result=$(transcribe_file "$TMPFILE" " ")

if [[ -z "$result" ]]; then
  echo "No speech detected."
  exit 0
fi

echo "$result"
echo ""

case "$key" in
  "")
    [[ -n "$TMUX" ]] && deliver_result paste "$result" || deliver_result copy "$result"
    ;;
  $'\e')
    deliver_result copy "$result"
    ;;
esac
# Ctrl+C: EXIT trap fires, nothing pasted/copied
