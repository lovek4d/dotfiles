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

## pick a tailnet device from `tailscale status` output
_ts_pick_device() {
  local prompt=$1
  tailscale status | awk 'NR>1 && $2 != "" { print $2 }' \
    | __fzf --prompt="$prompt"
}

## SSH to tailnet device (inline or fzf pick)
tssh() {
  local device="$1" ip
  if [[ -z "$device" ]]; then
    local selection
    selection=$(tailscale status | awk 'NR>1 && $2 != "" { print $1, $2 }' \
      | __fzf --prompt='ssh device> ')
    [[ -z "$selection" ]] && return 1
    ip="${selection%% *}" device="${selection##* }"
  else
    ip=$(tailscale status | awk -v d="$device" '$2 == d { print $1; exit }')
    [[ -z "$ip" ]] && echo "tssh: device '$device' not found in tailnet" >&2 && return 1
  fi
  ssh "$ip"
}

## ping tailnet device (inline or fzf pick)
tsping() {
  local device=${1:-$(_ts_pick_device 'ping device> ')}
  [[ -z "$device" ]] && return 1
  tailscale ping "$device"
}
