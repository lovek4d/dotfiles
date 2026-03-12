v() {
  if [[ $# -gt 0 ]]; then
    vim "$@"
    return
  fi
  cat <<'EOF'
vim aliases:
  settings
    VIMINIT    sources ~/dev/dotfiles/configs/vimrc
    undodir    ~/.vim/undo (persistent undo)
EOF
}

# ensure undo dir exists
[[ -d ~/.vim/undo ]] || mkdir -p ~/.vim/undo

# point vim at repo-managed config
export VIMINIT='source ~/dev/dotfiles/configs/vimrc'
