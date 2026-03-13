# auto-sudo for docker on Linux when socket isn't writable
if __is_linux && [[ ! -w /var/run/docker.sock ]]; then
  _dcmd() { sudo docker "$@"; }
  _dccmd() { sudo docker compose "$@"; }
else
  _dcmd() { docker "$@"; }
  _dccmd() { docker compose "$@"; }
fi

# helpers
# usage: _d_pick <prompt> <docker-cmd-args...> [-- <fzf-args...>]
_d_pick() {
  local prompt="${1:-container> }"; shift
  local dcmd_args=() fzf_args=() past_sep=0
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then past_sep=1; continue; fi
    if (( past_sep )); then fzf_args+=("$arg"); else dcmd_args+=("$arg"); fi
  done
  _dcmd "${dcmd_args[@]}" 2>/dev/null | __fzf --prompt="$prompt" "${fzf_args[@]}"
}

# core
d() {
  if [[ $# -gt 0 ]]; then
    _dcmd "$@"
    return
  fi
  cat <<'EOF'
docker aliases:
  containers
    dps     docker ps
    dpsa    docker ps -a
    dlog    logs -f (fzf running)
    dex     exec -it sh (fzf running)
    drun    run -it --rm
    dst     stop (fzf running)
    dsta    start (fzf stopped)
    drs     restart (fzf running)
    drm     rm (fzf stopped, multi)

  images (di prefix)
    di      docker images
    dib     docker build -t
    dipl    docker pull
    dips    docker push
    dit     docker tag
    dirm    rmi (fzf, multi)

  compose (dc prefix)
    dc      docker compose (passthrough)
    dcu     up -d
    dcub    up -d --build
    dcd     down
    dcl     logs -f
    dcps    ps
    dcrs    restart
    dcb     build

  cleanup & inspect
    dprune   system prune -a --volumes
    dvprune  volume prune
    dins     inspect (fzf)
    dstat    stats
    dnet     network ls
EOF
}

# containers
dps()  { _dcmd ps "$@"; }
dpsa() { _dcmd ps -a "$@"; }
drun() { _dcmd run -it --rm "$@"; }

dlog() {
  local ctr=${1:-$(_d_pick 'logs> '    ps --format '{{.Names}}')}
  [[ -z "$ctr" ]] && return 1
  _dcmd logs -f "$ctr"
}

dex() {
  local ctr=${1:-$(_d_pick 'exec> '    ps --format '{{.Names}}')}
  [[ -z "$ctr" ]] && return 1
  _dcmd exec -it "$ctr" /bin/sh
}

dst() {
  local ctr=${1:-$(_d_pick 'stop> '    ps --format '{{.Names}}')}
  [[ -z "$ctr" ]] && return 1
  _dcmd stop "$ctr"
}

dsta() {
  local ctr=${1:-$(_d_pick 'start> '   ps -a --filter 'status=exited' --format '{{.Names}}')}
  [[ -z "$ctr" ]] && return 1
  _dcmd start "$ctr"
}

drs() {
  local ctr=${1:-$(_d_pick 'restart> ' ps --format '{{.Names}}')}
  [[ -z "$ctr" ]] && return 1
  _dcmd restart "$ctr"
}

drm() {
  if [[ -n "$1" ]]; then
    _dcmd rm "$@"
    return
  fi
  local ctrs
  ctrs=$(_d_pick 'rm> '    ps -a --filter 'status=exited' --format '{{.Names}}' -- --multi)
  [[ -z "$ctrs" ]] && return 1
  echo "$ctrs" | xargs _dcmd rm
}

# images
di()   { _dcmd images "$@"; }
dib()  { _dcmd build -t "$@"; }
dipl() { _dcmd pull "$@"; }
dips() { _dcmd push "$@"; }
dit()  { _dcmd tag "$@"; }

dirm() {
  if [[ -n "$1" ]]; then
    _dcmd rmi "$@"
    return
  fi
  local imgs
  imgs=$(_d_pick 'rmi> '   images --format '{{.Repository}}:{{.Tag}}' -- --multi)
  [[ -z "$imgs" ]] && return 1
  echo "$imgs" | xargs _dcmd rmi
}

# compose
dc() {
  if [[ $# -gt 0 ]]; then
    _dccmd "$@"
    return
  fi
  _dccmd
}
dcu()  { _dccmd up -d "$@"; }
dcub() { _dccmd up -d --build "$@"; }
dcd()  { _dccmd down "$@"; }
dcl()  { _dccmd logs -f "$@"; }
dcps() { _dccmd ps "$@"; }
dcrs() { _dccmd restart "$@"; }
dcb()  { _dccmd build "$@"; }

# cleanup & inspect
dprune()  { _dcmd system prune -a --volumes "$@"; }
dvprune() { _dcmd volume prune "$@"; }
dstat()   { _dcmd stats "$@"; }
dnet()    { _dcmd network ls "$@"; }

dins() {
  local ctr=${1:-$(_d_pick 'inspect> ' ps -a --format '{{.Names}}')}
  [[ -z "$ctr" ]] && return 1
  _dcmd inspect "$ctr"
}
