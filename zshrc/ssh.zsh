# ssh passthrough
s() {
  if [[ $# -eq 0 ]]; then
    cat <<'EOF'
ssh aliases:
  connect
    s <args>   ssh (passthrough)
    ss [host]  fzf host picker from ~/.ssh/config
  keys
    skey       generate ed25519 key + copy pubkey
    sagent     start ssh-agent + add default key
EOF
    return 0
  fi
  ssh "$@"
}

# fzf host picker from ~/.ssh/config
ss() {
  if [[ -n "$1" ]]; then
    ssh "$1"
    return
  fi
  local host
  host=$(awk '/^Host / && !/\*/ { print $2 }' ~/.ssh/config 2>/dev/null | fzf --prompt="ssh> ") || return 0
  ssh "$host"
}

# generate ed25519 key + copy pubkey
skey() {
  local email="${1:-$(git config user.email)}"
  [[ -z "$email" ]] && echo "usage: skey <email>" && return 1
  local keyfile="$HOME/.ssh/id_ed25519"
  ssh-keygen -t ed25519 -C "$email" -f "$keyfile" || return 1
  clipcopy < "${keyfile}.pub"
  echo "public key copied to clipboard"
}

# start ssh-agent if not running, add default key
sagent() {
  if [[ -z "$SSH_AUTH_SOCK" ]] || ! ssh-add -l &>/dev/null; then
    eval "$(ssh-agent -s)"
  fi
  ssh-add ~/.ssh/id_ed25519 2>/dev/null || ssh-add
}
