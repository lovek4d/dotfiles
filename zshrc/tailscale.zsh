ts() {
  if [[ $# -gt 0 ]]; then
    tailscale "$@"
    return
  fi
  cat <<'EOF'
tailscale aliases:
  status
    tss     tailscale status
    tsip    show tailnet IPv4
    tsnet   network diagnostics

  connect
    tsu     tailscale up
    tsd     tailscale down
    tsinit  authenticate + join tailnet

  devices
    tssh [device]   SSH to tailnet device (fzf)
    tmosh [device]  mosh to tailnet device (fzf)
    tsping [device] ping tailnet device (fzf)
EOF
}

# simple aliases
alias tss='tailscale status'
alias tsu='tailscale up'
alias tsd='tailscale down'
alias tsip='tailscale ip -4'
alias tsnet='tailscale netcheck'

## start tailscaled + authenticate and join tailnet
tsinit() {
  if __is_macos; then
    # tailscaled needs root for TUN device on macOS
    brew services stop tailscale 2>/dev/null
    sudo brew services start tailscale 2>/dev/null
    echo "waiting for tailscaled..."
    local i=0
    while ! tailscale status &>/dev/null && (( i++ < 10 )); do sleep 1; done
    tailscale up
    echo "tailscale connected"
  else
    sudo tailscale up
    echo "tailscale connected"
  fi
}

## tailnet devices, one "<ip> <name>" per line — the list both pickers read
_ts_devices() {
  tailscale status | awk 'NR>1 && $2 != "" { print $1, $2 }'
}

## resolve a tailnet device to its IP — by name if given, else fzf pick
_ts_device_ip() {
  local verb="$1" device="$2" ip
  if [[ -z "$device" ]]; then
    ip=$(_ts_devices | __pick "$verb device> ") || return 1
    print -r -- "${ip%% *}"
    return
  fi
  ip=$(_ts_devices | awk -v d="$device" '$2 == d { print $1; exit }')
  [[ -z "$ip" ]] && echo "${funcstack[2]}: device '$device' not found in tailnet" >&2 && return 1
  print -r -- "$ip"
}

## SSH to tailnet device (inline or fzf pick)
tssh() {
  local ip
  ip=$(_ts_device_ip ssh "$1") || return 1
  ssh "$ip"
}

## mosh to tailnet device (inline or fzf pick). mosh starts the server over a
## non-interactive ssh, which never reads .zshrc — so a Homebrew mosh-server on
## a mac isn't on PATH. Prepend both brew prefixes; harmless on linux.
tmosh() {
  local ip
  ip=$(_ts_device_ip mosh "$1") || return 1
  mosh --server='PATH=/opt/homebrew/bin:/usr/local/bin:$PATH mosh-server' "$ip"
}

## ping tailnet device (inline or fzf pick)
tsping() {
  local device="$1"
  if [[ -z "$device" ]]; then
    device=$(_ts_devices | __pick 'ping device> ') || return 1
    device="${device##* }"
  fi
  tailscale ping "$device"
}
