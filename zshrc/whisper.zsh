w() {
  cat <<'EOF'
whisper aliases:
  winit   install whisper-cli + sox; download model
  wstart  start recording (Enter to stop and transcribe)
  wstop   kill a stuck recording

hotkey
  prefix+v      tmux popup (both platforms)
  macOS global  bind a Shortcut to scripts/whisper/window.command

model: ggml-large-v3-turbo (~809MB, in ~/.whisper/models/)
EOF
}

winit() {
  mkdir -p ~/.whisper/models

  if __is_macos; then
    echo "=== whisper deps (brew) ==="
    for pkg in whisper-cpp sox; do
      if brew list "$pkg" &>/dev/null; then
        echo "$pkg already installed"
      else
        brew install "$pkg"
      fi
    done

  elif __is_linux; then
    if ! command -v whisper-cli &>/dev/null; then
      echo "=== building whisper.cpp from source ==="
      sudo apt install -y build-essential cmake
      local build_dir="$HOME/.whisper/whisper.cpp"
      git clone https://github.com/ggerganov/whisper.cpp.git "$build_dir" 2>/dev/null || git -C "$build_dir" pull
      cmake -B "$build_dir/build" -S "$build_dir"
      cmake --build "$build_dir/build" --config Release -j$(nproc)
      sudo cp "$build_dir/build/bin/whisper-cli" /usr/local/bin/whisper-cli
      echo "whisper-cli installed to /usr/local/bin/"
    else
      echo "whisper-cli already installed"
    fi
  fi

  local model="$HOME/.whisper/models/ggml-large-v3-turbo.bin"
  if [[ -f "$model" ]]; then
    echo "model already downloaded"
  else
    echo "downloading ggml-large-v3-turbo (~809MB)..."
    curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin" \
      -o "$model" --progress-bar
  fi

  echo "whisper ready"
  __is_macos && echo "  global hotkey: bind a Shortcut to ~/dev/dotfiles/scripts/whisper/window.command"
  echo "  tmux hotkey:   prefix+v"
}

wstart() {
  ~/dev/dotfiles/scripts/whisper/record.sh
}

wstop() {
  if pkill -INT -f "rec.*whisper-rec-raw.wav" 2>/dev/null; then
    echo "recording stopped"
  else
    echo "not recording"
  fi
}
