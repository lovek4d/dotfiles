local HOME = os.getenv("HOME")
local TMPRAW = "/tmp/whisper-rec-raw.wav"
local TMPFILE = "/tmp/whisper-rec.wav"
local MODEL = HOME .. "/.whisper/models/ggml-large-v3-turbo.bin"
local PROMPT = "Software engineering discussion."

local recTask = nil

local function notify(msg, persistent)
  hs.notify.withdrawAll()
  local attrs = {title = "Whisper", informativeText = msg}
  if persistent then attrs.withdrawAfter = 0 end
  local n = hs.notify.new(nil, attrs):send()
end

local function transcribe()
  hs.notify.withdrawAll()
  local soxTask = hs.task.new("/opt/homebrew/bin/sox", function(_, _, _)
    os.remove(TMPRAW)
    local whisperTask = hs.task.new("/opt/homebrew/bin/whisper-cli", function(_, stdout, _)
      os.remove(TMPFILE)
      local result = stdout:gsub("%[BLANK_AUDIO%]", ""):gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if result ~= "" then
        hs.pasteboard.setContents(result)
        notify("Transcription copied to clipboard:\n" .. result)
      else
        notify("No speech detected")
      end
    end, {"-m", MODEL, "-f", TMPFILE, "--no-timestamps", "-l", "en", "--prompt", PROMPT})
    whisperTask:start()
  end, {TMPRAW, "-r", "16000", "-b", "16", "-e", "signed-integer", TMPFILE})
  soxTask:start()
end

-- ctrl+shift+v → toggle whisper voice recording
hs.hotkey.bind({"ctrl", "shift"}, "v", function()
  if recTask and recTask:isRunning() then
    recTask:interrupt()
    recTask = nil
  else
    recTask = hs.task.new("/opt/homebrew/bin/rec", function(_, _, _)
      transcribe()
    end, {"-q", "-c", "1", TMPRAW})
    recTask:start()
    notify("Recording...", true)
  end
end)
