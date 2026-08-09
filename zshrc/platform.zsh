# platform detection
__is_macos() { [[ "$OSTYPE" == darwin* ]]; }
__is_linux() { [[ "$OSTYPE" == linux* ]]; }

# clipboard abstraction
unalias clipcopy clippaste 2>/dev/null
unfunction clipcopy clippaste 2>/dev/null
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

## keep the machine awake for <seconds>; prints the pid holding it awake
## (nothing, and no pid, where the platform has no inhibitor)
__keep_awake() {
  local secs="$1"
  if __is_macos; then
    caffeinate -di -t "$secs" & print -r -- $!
  elif command -v systemd-inhibit >/dev/null 2>&1; then
    systemd-inhibit --what=idle --why="keep awake" sleep "$secs" & print -r -- $!
  fi
}

## synthesise a Return keypress into the focused window
__press_enter() {
  if __is_macos; then
    osascript -e 'tell application "System Events" to key code 36'
  elif command -v xdotool >/dev/null 2>&1; then
    xdotool key Return
  else
    echo "press-enter: needs xdotool on this platform" >&2
    return 1
  fi
}

## print the first path that exists and is non-empty; non-zero if none do.
## Empty arguments are skipped, so "${_BREW_PFX:+...}" can be passed directly.
__first_file() {
  local p
  for p in "$@"; do
    [[ -n "$p" && -s "$p" ]] && { print -r -- "$p"; return 0; }
  done
  return 1
}

## symlink a repo config into place, replacing an existing link.
## Refuses to clobber a real file; announces what it linked.
__link_config() {
  local src="$1" dest="$2"
  [[ -e "$src" ]] || { echo "link: missing source $src" >&2; return 1; }
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    echo "link: $dest exists and is not a symlink — leaving it alone" >&2
    return 1
  fi
  mkdir -p "${dest:h}" || return 1
  ln -sfn "$src" "$dest" || return 1
  echo "symlinked $dest -> $src"
}
