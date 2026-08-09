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

test_tssh_resolves_a_named_device_to_its_ip() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" "100.2.2.2 nas" ;; esac'
  stub ssh; stub fzf
  load tailscale
  tssh nas
  assert_called "ssh 100.2.2.2"
  assert_not_called "fzf"
}

test_tssh_picker_ssh_es_to_the_ip_not_the_name() {
  stub_fn tailscale 'case "$1" in status) print -rl -- "HEADER" "100.1.1.1 laptop" "100.2.2.2 nas" ;; esac'
  stub ssh; stub fzf "100.2.2.2 nas"
  load tailscale
  tssh
  assert_called "ssh 100.2.2.2"
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

# ssh

test_sc_with_arg_skips_the_picker() {
  stub ssh; stub fzf; stub ssh-add
  load ssh
  sc myhost
  assert_called "ssh myhost"
  assert_not_called "fzf"
}

run_tests
