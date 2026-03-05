__ssh_show_pubkey() {
  clipcopy < "${1}.pub" 2>/dev/null && echo "public key copied to clipboard" \
    || echo "public key:\n$(cat "${1}.pub")"
}

# auto-load ssh key into agent
if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
  ssh-add -l &>/dev/null || ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi

# ssh passthrough
s() {
  if [[ $# -eq 0 ]]; then
    cat <<'EOF'
ssh aliases:
  connect
    s <args>      ssh (passthrough)
    ss [host]     fzf host picker from ~/.ssh/config
  keys
    sinit [email] generate key + add to agent + copy pubkey
    scid <host>   copy public key to remote host for passwordless login
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

# copy public key to remote host (passwordless login)
scid() {
  [[ -z "$1" ]] && echo "usage: scid <host>" && return 1
  ssh-copy-id "$1"
}

# generate key + add to agent + copy pubkey
sinit() {
  local comment="${1:-$(whoami)@$(hostname -s)}"
  local keyfile="$HOME/.ssh/id_ed25519"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  if [[ -f "$keyfile" ]]; then
    echo "ssh key already exists: $keyfile"
  else
    echo "generating ssh key (no passphrase)..."
    ssh-keygen -t ed25519 -C "$comment" -f "$keyfile" -N "" || return 1
  fi
  ssh-add "$keyfile" 2>/dev/null
  __ssh_show_pubkey "$keyfile"
  echo "add to GitHub: https://github.com/settings/ssh/new"
}
