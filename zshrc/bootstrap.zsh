# Machine bootstrap
__confirm() {
  local reply
  read "reply?$1 [y/N] "
  [[ "$reply" == [Yy]* ]]
}

__load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"
  if [[ -n "${_BREW_PFX:-}" ]]; then
    [ -s "$_BREW_PFX/opt/nvm/nvm.sh" ] && \. "$_BREW_PFX/opt/nvm/nvm.sh"
  fi
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

__ensure_node() {
  command -v npx >/dev/null 2>&1 && return 0

  __load_nvm
  if ! command -v nvm >/dev/null 2>&1; then
    echo "skipped node: nvm missing"
    return 1
  fi

  echo "=== node ==="
  nvm install --lts
  nvm use --lts
}

__agent_setup_core() {
  echo "=== claude settings ==="
  cinit || return 1
  __ensure_node || return 1
}

__agent_install_mattpocock_skills() {
  if command -v npx >/dev/null 2>&1; then
    npx skills add mattpocock/skills -g
  else
    echo "skipped: npx missing"
    echo "run later: npx skills add mattpocock/skills -g"
  fi
}

__agent_install_claude_ponytail() {
  if command -v claude >/dev/null 2>&1; then
    claude plugin marketplace add DietrichGebert/ponytail
    claude plugin install ponytail@ponytail --scope user
  else
    echo "skipped Claude Ponytail: claude missing"
  fi
}

__agent_install_codex_ponytail() {
  if command -v codex >/dev/null 2>&1; then
    codex plugin marketplace add DietrichGebert/ponytail
    codex plugin add ponytail@ponytail
  else
    echo "skipped Codex Ponytail: codex missing"
    echo "run later: codex plugin marketplace add DietrichGebert/ponytail"
    echo "then: codex plugin add ponytail@ponytail"
  fi
}

__agent_install_ponytail() {
  __agent_install_claude_ponytail
  __agent_install_codex_ponytail
  echo "Ponytail installed where available; restart Claude/Codex, then enable/disable it from plugin controls and trust hooks if prompted"
}

__agent_install_optional_extras() {
  echo "=== optional agent extras ==="

  if __confirm "Install Matt Pocock engineering skills for Claude/Codex?"; then
    __agent_install_mattpocock_skills
  fi

  if __confirm "Install Ponytail for Claude Code and Codex?"; then
    __agent_install_ponytail
  fi
}

ainit() {
  __agent_setup_core || return 1
  __agent_install_optional_extras
}

zinit() {
  local pkgs=(git fzf tmux vim python3 pipx zsh-autosuggestions zsh-syntax-highlighting zoxide ripgrep bat jq sd)

  if __is_macos; then
    _zinit_macos "${pkgs[@]}" nvm colima docker starship tailscale fd
  elif __is_linux; then
    _zinit_linux "${pkgs[@]}" zsh curl xclip docker.io fd-find
  else
    echo "unsupported platform: $OSTYPE" && return 1
  fi

  __ensure_node

  echo "=== pipx packages ==="
  local pkg pipx_installed=$(pipx list --short 2>/dev/null | awk '{print $1}')
  for pkg in tldr; do
    if echo "$pipx_installed" | grep -qx "$pkg"; then
      echo "$pkg up to date"
    else
      echo "installing $pkg..."
      pipx install "$pkg"
    fi
  done

  echo "=== git ==="
  ginit

  echo "=== tmux ==="
  tminit

  echo "=== starship ==="
  mkdir -p "$HOME/.config"
  ln -sf "$HOME/dev/dotfiles/configs/starship.toml" "$HOME/.config/starship.toml"
  echo "symlinked ~/dev/dotfiles/configs/starship.toml -> ~/.config/starship.toml"

  echo "=== ssh ==="
  sinit

  echo "=== claude ==="
  if ! command -v claude >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | bash
  fi

  echo "=== done ==="
  echo "run 'ainit' for Claude settings/hooks and optional agent skills/plugins"
  echo "run 'winit' for whisper voice transcription (opt-in)"
  source ~/.zshrc
}

_zinit_macos() {
  # xcode command line tools
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "=== xcode command line tools ==="
    xcode-select --install
    echo "re-run zinit after xcode tools finish installing"
    return 0
  fi

  # homebrew
  if ! command -v brew >/dev/null 2>&1; then
    echo "=== installing homebrew ==="
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  _BREW_PFX=$(brew --prefix)

  echo "=== brew packages ==="
  local pkg missing=() outdated=() installed outdated_list
  installed=$(brew list --formula -1)
  outdated_list=$(brew outdated --formula -1 2>/dev/null)
  for pkg in "$@"; do
    if echo "$installed" | grep -qx "$pkg"; then
      if echo "$outdated_list" | grep -qx "$pkg"; then
        outdated+=("$pkg")
      else
        echo "$pkg up to date"
      fi
    else
      missing+=("$pkg")
    fi
  done
  local i=1 total=$(( ${#missing[@]} + ${#outdated[@]} ))
  for pkg in "${missing[@]}"; do
    echo "installing $pkg ($i/$total)..."
    brew install "$pkg"
    ((i++))
  done
  for pkg in "${outdated[@]}"; do
    echo "upgrading $pkg ($i/$total)..."
    brew upgrade "$pkg"
    ((i++))
  done
  brew services start colima &>/dev/null && echo "colima registered as startup service" || echo "colima service registration failed"
}

_zinit_linux() {
  echo "=== apt packages ==="
  sudo apt update
  local pkg
  for pkg in "$@"; do
    sudo apt install -y "$pkg" 2>/dev/null || echo "skipped: $pkg (not available in apt)"
  done

  # add user to docker group (takes effect on next login)
  if getent group docker >/dev/null 2>&1 && ! groups | grep -qw docker; then
    echo "=== adding $USER to docker group ==="
    sudo usermod -aG docker "$USER"
    echo "docker group added (re-login to take effect)"
  fi

  # nvm via install script
  export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    echo "=== installing nvm ==="
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  fi

  # starship prompt
  if ! command -v starship >/dev/null 2>&1; then
    echo "=== installing starship ==="
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi

  # tailscale
  if ! command -v tailscale >/dev/null 2>&1; then
    echo "=== installing tailscale ==="
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  # set zsh as default shell
  if [[ "$SHELL" != */zsh ]]; then
    echo "=== setting zsh as default shell ==="
    chsh -s "$(which zsh)"
  fi
}
