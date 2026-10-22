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
    tssw [tailnet]  switch tailnet/account (fzf)

  devices
    tssh [device]   SSH to tailnet device (fzf)
    tmosh [device]  mosh to tailnet device (fzf)
    tscid [device]  copy ssh key to tailnet device (fzf)
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

## switch tailnet/account (inline or fzf pick). The list's current entry
## carries a trailing '*'; the pick resolves to its ID column.
tssw() {
  local target="$1"
  if [[ -z "$target" ]]; then
    target=$(tailscale switch --list | awk 'NR>1' | __pick 'switch tailnet> ') || return 1
    target="${target%% *}"
  fi
  tailscale switch "$target"
}

## tailnet devices, one "<ip> <name>" per line — the list the picker reads
_ts_devices() {
  tailscale status | awk 'NR>1 && $2 != "" { print $1, $2 }'
}

## resolve a tailnet device to its MagicDNS short name — validated if given,
## else fzf pick. Errors name the user-facing command (first non-_ frame).
_ts_device_name() {
  local verb="$1" device="$2" name
  if [[ -z "$device" ]]; then
    name=$(_ts_devices | __pick "$verb device> ") || return 1
    print -r -- "${name##* }"
    return
  fi
  name=$(_ts_devices | awk -v d="$device" '$2 == d { print $2; exit }')
  if [[ -z "$name" ]]; then
    local -a cmds=(${funcstack:#_*})
    echo "${cmds[1]}: device '$device' not found in tailnet" >&2
    return 1
  fi
  print -r -- "$name"
}

## does key auth to a host already work? Non-interactive, so an unknown host
## key or an unreachable device also counts as no.
_ts_key_auth_ok() {
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$1" true &>/dev/null
}

## prompt for a remote user, print "<user>@<host>" (Enter keeps the default)
_ts_ask_user() {
  local host="$1" user
  print -n -u2 -- "user for $host [$USER]: "
  read -r user
  print -r -- "${user:+$user@}$host"
}

## the seam every ssh-family command (tssh/tmosh/tspull) connects through:
## resolve a device to "[user@]<name>" — the bare name if key auth already
## works, else prompt for the user. By name rather than IP so ~/.ssh/config
## `Host <name>` blocks (e.g. a per-device User) apply, and known_hosts
## records the name.
_ts_ssh_target() {
  local host
  host=$(_ts_device_name "$@") || return 1
  if _ts_key_auth_ok "$host"; then
    print -r -- "$host"
  else
    _ts_ask_user "$host"
  fi
}

## SSH to tailnet device (inline or fzf pick)
tssh() {
  local target
  target=$(_ts_ssh_target ssh "$1") || return 1
  ssh "$target"
}

## mosh to tailnet device (inline or fzf pick). mosh starts the server over a
## non-interactive ssh, which never reads .zshrc — so a Homebrew mosh-server on
## a mac isn't on PATH. Prepend both brew prefixes; harmless on linux.
tmosh() {
  local target
  target=$(_ts_ssh_target mosh "$1") || return 1
  mosh --server='PATH=/opt/homebrew/bin:/usr/local/bin:$PATH mosh-server' "$target"
}

## copy ssh public key to tailnet device (inline or fzf pick) so tssh/tmosh
## stop prompting. A no-op if key auth already works.
tscid() {
  local host
  host=$(_ts_device_name scid "$1") || return 1
  if _ts_key_auth_ok "$host"; then
    echo "tscid: key auth to $host already works"
    return
  fi
  ssh-copy-id "$(_ts_ask_user "$host")"
}

## ping tailnet device (inline or fzf pick)
tsping() {
  local device
  device=$(_ts_device_name ping "$1") || return 1
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

  local root rel
  root="$(__git_repo_root 2>/dev/null)" || { echo "tspull: not in a git repo" >&2; return 1; }
  rel="${root#$HOME/}"

  local target
  target=$(_ts_ssh_target pull "$1") || return 1

  "$rsync_bin" -avz --delete --exclude .git --filter=':- .gitignore' "${target}:~/${rel}/" "${root}/"
}
