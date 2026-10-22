#!/usr/bin/env zsh
# Every domain module reaches the same selection module. These pin the
# arg-passthrough / pick / cancel contract at each call site.
source "${0:A:h}/lib.zsh"

# docker

test_dlog_with_arg_skips_the_picker() {
  stub docker; stub fzf
  load docker
  dlog web
  assert_called "docker logs -f web"
  assert_not_called "fzf"
}

test_dlog_without_arg_picks_a_running_container() {
  stub_fn docker 'case "$*" in "ps --format {{.Names}}") print -rl -- web db ;; esac'
  stub fzf db
  load docker
  dlog
  assert_called "docker logs -f db"
}

test_dsta_picks_from_stopped_containers() {
  stub_fn docker 'case "$*" in *status=exited*) print -rl -- old ;; esac'
  stub fzf old
  load docker
  dsta
  assert_called "docker start old"
}

test_drm_multi_select_removes_all_chosen() {
  stub_fn docker 'case "$*" in *status=exited*) print -rl -- a b ;; esac'
  stub fzf $'a\nb'
  load docker
  drm
  assert_called "docker rm a b"
}

test_drm_cancelled_removes_nothing() {
  stub docker; stub fzf ""
  load docker
  drm
  assert_not_called "docker rm"
}

# tmux

test_tms_with_arg_skips_the_picker() {
  stub tmux; stub fzf
  load tmux
  tms work
  assert_not_called "fzf"
  assert_called "tmux "
}

test_tmk_picks_a_session() {
  stub_fn tmux 'case "$*" in "list-sessions -F #{session_name}") print -rl -- work play ;; esac'
  stub fzf play
  load tmux
  tmk
  assert_called "tmux kill-session -t play"
}

# tailscale

test_tssh_connects_to_a_named_device_by_name() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" "100.2.2.2 nas" ;; esac'
  stub ssh; stub fzf
  load tailscale
  tssh nas
  assert_called "ssh nas"
  assert_not_called "100.2.2.2"
  assert_not_called "fzf"
}

test_tssh_picker_ssh_es_to_the_name_not_the_ip() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" "100.2.2.2 nas" ;; esac'
  stub ssh; stub fzf "100.2.2.2 nas"
  load tailscale
  tssh
  assert_called "ssh nas"
  assert_not_called "100.2.2.2"
}

test_tssh_unauthed_prompts_for_a_user() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.2.2.2 nas" ;; esac'
  stub_fn ssh '[[ "$*" == *BatchMode* ]] && return 255; return 0'
  load tailscale
  tssh nas <<< "alice" 2>/dev/null
  assert_called "ssh alice@nas"
}

test_tssh_unauthed_empty_user_keeps_the_default() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.2.2.2 nas" ;; esac'
  stub_fn ssh '[[ "$*" == *BatchMode* ]] && return 255; return 0'
  load tailscale
  tssh nas <<< "" 2>/dev/null
  assert_called "ssh nas"
  assert_not_called "@nas"
}

test_tssh_authed_does_not_prompt() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.2.2.2 nas" ;; esac'
  stub ssh
  load tailscale
  local err
  err=$(tssh nas <<< "alice" 2>&1 >/dev/null)
  assert_eq "" "$err"
  assert_not_called "alice@"
}

test_tmosh_unauthed_prompts_for_a_user() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.2.2.2 nas" ;; esac'
  stub_fn ssh 'return 255'
  stub mosh
  load tailscale
  tmosh nas <<< "alice" 2>/dev/null
  assert_called "mosh-server alice@nas"
}

test_tscid_picker_copies_the_key_as_the_prompted_user() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" "100.2.2.2 nas" ;; esac'
  stub_fn ssh 'return 255'
  stub ssh-copy-id; stub fzf "100.2.2.2 nas"
  load tailscale
  tscid <<< "alice" 2>/dev/null
  assert_called "ssh-copy-id alice@nas"
}

test_tscid_skips_when_key_auth_already_works() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.2.2.2 nas" ;; esac'
  stub ssh; stub ssh-copy-id
  load tailscale
  tscid nas >/dev/null
  assert_not_called "ssh-copy-id"
}

test_tswho_picker_queries_the_ip_not_the_name() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" "100.2.2.2 nas" ;; esac'
  stub fzf "100.2.2.2 nas"
  load tailscale
  tswho
  assert_called "tailscale whois 100.2.2.2"
}

test_tswho_unknown_device_names_the_caller() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" ;; esac'
  load tailscale
  local err
  err=$(tswho nope 2>&1)
  assert_err $?
  assert_eq "tswho: device 'nope' not found in tailnet" "$err"
  assert_not_called "tailscale whois"
}

test_tsping_picker_pings_the_name_not_the_ip() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" ;; esac'
  stub fzf "100.1.1.1 laptop"
  load tailscale
  tsping
  assert_called "tailscale ping laptop"
}

test_tssh_unknown_device_does_not_connect() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" ;; esac'
  stub ssh
  load tailscale
  tssh nope 2>/dev/null
  assert_err $?
  assert_not_called "ssh "
}

test_tmosh_connects_to_a_named_device_by_name() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" "100.2.2.2 nas" ;; esac'
  stub mosh; stub fzf
  load tailscale
  tmosh nas
  assert_called "mosh --server=PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH mosh-server nas"
  assert_not_called "fzf"
}

test_tmosh_picker_moshes_to_the_name_not_the_ip() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" "100.2.2.2 nas" ;; esac'
  stub mosh; stub fzf "100.2.2.2 nas"
  load tailscale
  tmosh
  assert_called "mosh-server nas"
}

test_tmosh_cancelled_pick_does_not_connect() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" ;; esac'
  stub mosh; stub fzf ""
  load tailscale
  tmosh
  assert_err $?
  assert_not_called "mosh --server"
}

test_tmosh_unknown_device_names_the_caller() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" ;; esac'
  stub mosh
  load tailscale
  local err
  err=$(tmosh nope 2>&1)
  assert_err $?
  assert_eq "tmosh: device 'nope' not found in tailnet" "$err"
  assert_not_called "mosh --server"
}

test_tspull_rsyncs_from_the_device_by_name() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.2.2.2 nas" ;; esac'
  stub ssh; stub rsync
  load tailscale
  stub_rc __is_macos 1; stub __is_macos
  stub_fn __git_repo_root 'print -r -- "$HOME/dev/repo"'
  tspull nas
  assert_called "nas:~/dev/repo/"
  assert_not_called "100.2.2.2"
}

test_tspull_outside_a_repo_does_not_prompt() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.2.2.2 nas" ;; esac'
  stub_fn ssh 'return 255'; stub rsync
  load tailscale
  stub_rc __is_macos 1; stub __is_macos
  stub_rc __git_repo_root 1; stub __git_repo_root
  local err
  err=$(tspull nas <<< "alice" 2>&1)
  assert_err $?
  assert_eq "tspull: not in a git repo" "$err"
}

test_tssw_picker_switches_to_the_id() {
  stub_fn tailscale 'case "$1" in switch) [[ "$2" == --list ]] && print -rl -- "ID    Tailnet  Account" "bd16  home     me@github*" "a7f2  work     me@corp" ;; esac'
  stub fzf "a7f2  work     me@corp"
  load tailscale
  tssw
  assert_called "tailscale switch a7f2"
}

test_tssw_cancelled_pick_does_not_switch() {
  stub_fn tailscale 'case "$1" in switch) [[ "$2" == --list ]] && print -rl -- "ID  Tailnet  Account" "a7f2  work  me@corp" ;; esac'
  stub fzf ""
  load tailscale
  tssw
  assert_err $?
  assert_not_called "tailscale switch a7f2"
}

# ssh

test_sc_with_arg_skips_the_picker() {
  stub ssh; stub fzf; stub ssh-add
  load ssh
  sc myhost
  assert_called "ssh myhost"
  assert_not_called "fzf"
}

run_tests
