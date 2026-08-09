#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"

setup_tmpdir() {
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/plat.XXXXXX")"
}

# __first_file

test_first_file_skips_empty_arguments() {
  load
  setup_tmpdir
  print hi > "$TMP/real"
  assert_eq "$TMP/real" "$(__first_file "" "$TMP/real")"
  rm -rf "$TMP"
}

test_first_file_prefers_the_earlier_path() {
  load
  setup_tmpdir
  print a > "$TMP/one"; print b > "$TMP/two"
  assert_eq "$TMP/one" "$(__first_file "$TMP/one" "$TMP/two")"
  rm -rf "$TMP"
}

test_first_file_ignores_empty_files() {
  load
  setup_tmpdir
  : > "$TMP/empty"; print b > "$TMP/two"
  assert_eq "$TMP/two" "$(__first_file "$TMP/empty" "$TMP/two")"
  rm -rf "$TMP"
}

test_first_file_fails_when_nothing_exists() {
  load
  __first_file "" /nope/a /nope/b >/dev/null
  assert_err $?
}

# __link_config

test_link_config_creates_parent_and_links() {
  load
  setup_tmpdir
  print src > "$TMP/src"
  __link_config "$TMP/src" "$TMP/deep/nested/dest" >/dev/null
  assert_ok $?
  assert_eq "$TMP/src" "$(readlink "$TMP/deep/nested/dest")"
  rm -rf "$TMP"
}

test_link_config_replaces_an_existing_link() {
  load
  setup_tmpdir
  print a > "$TMP/a"; print b > "$TMP/b"
  ln -s "$TMP/a" "$TMP/dest"
  __link_config "$TMP/b" "$TMP/dest" >/dev/null
  assert_eq "$TMP/b" "$(readlink "$TMP/dest")"
  rm -rf "$TMP"
}

test_link_config_refuses_to_clobber_a_real_file() {
  load
  setup_tmpdir
  print src > "$TMP/src"; print precious > "$TMP/dest"
  __link_config "$TMP/src" "$TMP/dest" 2>/dev/null
  assert_err $?
  assert_eq precious "$(cat "$TMP/dest")"
  rm -rf "$TMP"
}

test_link_config_fails_on_missing_source() {
  load
  setup_tmpdir
  __link_config "$TMP/absent" "$TMP/dest" 2>/dev/null
  assert_err $?
  [[ -e "$TMP/dest" ]] && __fail "dest should not have been created"
  rm -rf "$TMP"
}

# platform seam

test_keep_awake_uses_caffeinate_on_macos() {
  stub caffeinate; stub systemd-inhibit
  load
  functions[__is_macos]='return 0'
  __keep_awake 60 >/dev/null
  assert_called "caffeinate -di -t 60"
}

test_press_enter_uses_osascript_on_macos() {
  stub osascript
  load
  functions[__is_macos]='return 0'
  __press_enter
  assert_called "osascript -e"
}

test_press_enter_falls_back_to_xdotool_off_macos() {
  stub osascript; stub xdotool
  load
  functions[__is_macos]='return 1'
  functions[command]='return 0'   # pretend xdotool is installed
  __press_enter
  assert_called "xdotool key Return"
  assert_not_called "osascript"
}

run_tests
