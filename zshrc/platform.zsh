# platform detection
__is_macos() { [[ "$OSTYPE" == darwin* ]]; }
__is_linux() { [[ "$OSTYPE" == linux* ]]; }

# clipboard abstraction
if __is_macos; then
  alias clipcopy='pbcopy'
  alias clippaste='pbpaste'
elif command -v xclip >/dev/null 2>&1; then
  alias clipcopy='xclip -selection clipboard'
  alias clippaste='xclip -selection clipboard -o'
else
  clipcopy()  { echo "clipcopy: install xclip (apt install xclip)"; return 1; }
  clippaste() { echo "clippaste: install xclip (apt install xclip)"; return 1; }
fi

# notification abstraction
__notify() {
  local msg="$1" title="${2:-Done}" sound="${3:-Glass}"
  if __is_macos; then
    osascript -e "display notification \"$msg\" with title \"$title\" sound name \"$sound\""
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$msg"
  fi
}
