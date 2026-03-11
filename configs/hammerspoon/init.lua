-- ctrl+shift+v → whisper voice recording popup in active tmux session
hs.hotkey.bind({"ctrl", "shift"}, "v", function()
  hs.task.new("/opt/homebrew/bin/tmux", nil, {
    "popup", "-E", "-w", "60", "-h", "6",
    os.getenv("HOME") .. "/dev/dotfiles/scripts/whisper/record.sh"
  }):start()
end)
