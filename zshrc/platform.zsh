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
