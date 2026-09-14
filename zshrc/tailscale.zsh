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
    tspull [device] rsync-pull cwd's repo root from tailnet device (fzf)
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

## rsync-pull the cwd's repo root from the same ~-relative path on a tailnet
## device (inline or fzf pick) — home dirs differ (/Users vs /home), so the
## remote side is addressed as ~/<path-relative-to-$HOME> and expanded by
## the remote shell. Mirrors exactly (--delete): local-only uncommitted
## files in that checkout will be clobbered. Skips .git and .gitignore'd
## paths. Missing remote dir surfaces as rsync's own error, unfiltered.
## macOS's system rsync is openrsync, which silently ignores --filter merge
## rules — so this needs Homebrew's real rsync, called by explicit path
## (bare `rsync` could still resolve to openrsync depending on PATH order).
tspull() {
  local rsync_bin=rsync
  if __is_macos; then
    rsync_bin=$(__first_file /opt/homebrew/bin/rsync /usr/local/bin/rsync) || {
      echo "tspull: needs Homebrew rsync (openrsync doesn't support --filter) — run 'brew install rsync'" >&2
      return 1
    }
  fi

  local ip
  ip=$(_ts_device_ip pull "$1") || return 1

  local root rel
  root="$(__git_repo_root 2>/dev/null)" || { echo "tspull: not in a git repo" >&2; return 1; }
  rel="${root#$HOME/}"

  "$rsync_bin" -avz --delete --exclude .git --filter=':- .gitignore' "${ip}:~/${rel}/" "${root}/"
}
