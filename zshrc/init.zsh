# platform detection (must be first)
source $HOME/dev/dotfiles/zshrc/platform.zsh

# history
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# keybindings
bindkey '\e[1;3D' backward-word        # option+left
bindkey '\e[1;3C' forward-word         # option+right
bindkey '\e\x7f'  backward-kill-word   # option+backspace
bindkey '\e[3~'   delete-char          # delete (fn+backspace)
bindkey '\e[3;3~' kill-word            # option+delete
bindkey '\e[H'    beginning-of-line    # home
bindkey '\e[F'    end-of-line          # end

# autocomplete (must be before sourcing files that use compdef)
if command -v brew >/dev/null 2>&1; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi
if [[ -d /usr/share/zsh/vendor-completions ]]; then
  FPATH="/usr/share/zsh/vendor-completions:${FPATH}"
fi
autoload -Uz promptinit && promptinit
autoload -Uz compinit && compinit

# source others
source $HOME/dev/dotfiles/zshrc/git.zsh
source $HOME/dev/dotfiles/zshrc/tmux.zsh
source $HOME/dev/dotfiles/zshrc/tailscale.zsh
source $HOME/dev/dotfiles/zshrc/funcs.zsh
source $HOME/dev/dotfiles/zshrc/claude.zsh
source $HOME/dev/dotfiles/zshrc/vim.zsh
source $HOME/dev/dotfiles/zshrc/ssh.zsh

# general
z() {
  cat <<'EOF'
zshrc aliases:
  general
    dev          cd ~/dev
    docker_prune docker system prune -a --volumes
    python       python3
    wdvenv       source .venv/bin/activate
  navigation
    j <dir>  zoxide jump
    ji       zoxide interactive
    mkcd     mkdir + cd
  dotfiles
    zinit  install/upgrade all deps
    zpl    git pull dotfiles + source
  zshrc
    zsrc   source .zshrc
    zup    zvim + zsrc
    zvim   edit .zshrc
  misc
    redact-json  redact JSON from clipboard
    pk           fzf process killer
    port <n>     show/kill process on port
  help
    c      claude aliases
    g      git aliases
    s      ssh aliases
    tm     tmux aliases
    ts     tailscale aliases
    v      vim aliases
EOF
}

# bootstrap
zinit() {
  local pkgs=(git fzf tmux python3 zsh-autosuggestions zsh-syntax-highlighting zoxide)

  if __is_macos; then
    _zinit_macos "${pkgs[@]}" nvm python@3 claude-code colima docker starship tailscale
  elif __is_linux; then
    _zinit_linux "${pkgs[@]}" zsh curl xclip docker.io
  else
    echo "unsupported platform: $OSTYPE" && return 1
  fi

  echo "=== tmux ==="
  tminit

  echo "=== starship ==="
  mkdir -p "$HOME/.config"
  ln -sf "$HOME/dev/dotfiles/configs/starship.toml" "$HOME/.config/starship.toml"
  echo "symlinked ~/dev/dotfiles/configs/starship.toml → ~/.config/starship.toml"

  echo "=== claude ==="
  cinit

  echo "=== done ==="
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

  echo "=== brew packages ==="
  brew install "$@" 2>&1 | grep -Ev "To reinstall|^  brew reinstall" | sed 's/^Warning: //'
  brew services start colima &>/dev/null && echo "colima registered as startup service" || echo "colima service registration failed"
}

_zinit_linux() {
  echo "=== apt packages ==="
  sudo apt update
  sudo apt install -y "$@"

  # nvm via install script
  export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    echo "=== installing nvm ==="
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  fi

  # load nvm + install node
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  if ! command -v node >/dev/null 2>&1; then
    echo "=== installing node via nvm ==="
    nvm install --lts
  fi

  # claude-code via npm
  if ! command -v claude >/dev/null 2>&1; then
    echo "=== installing claude-code ==="
    npm install -g @anthropic-ai/claude-code
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

# nav basics
alias dev='cd ~/dev'
mkcd() { mkdir -p "$1" && cd "$1"; }

# python basics
alias python='python3'
alias wdvenv='source .venv/bin/activate'

# nvm + autocomplete
export NVM_DIR="$HOME/.nvm"
if __is_macos && command -v brew >/dev/null 2>&1; then
  _brew_prefix="$(brew --prefix)"
  [ -s "$_brew_prefix/opt/nvm/nvm.sh" ] && \. "$_brew_prefix/opt/nvm/nvm.sh"
  [ -s "$_brew_prefix/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$_brew_prefix/opt/nvm/etc/bash_completion.d/nvm"
  unset _brew_prefix
else
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# dotfiles
alias zpl='git -C ~/dev/dotfiles pull && source ~/.zshrc'

# zshrc utils
alias zvim='${EDITOR:-vim} ~/.zshrc'
alias zsrc='source ~/.zshrc'
alias zup='zvim && zsrc'

# docker
alias docker_prune='docker system prune -a --volumes'

# brew shell init
if __is_macos; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# zoxide (j/ji)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd j)"
fi

# zsh plugins (syntax-highlighting must be last)
if __is_macos && command -v brew >/dev/null 2>&1; then
  _bp="$(brew --prefix)"
  [ -s "$_bp/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && source "$_bp/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [ -s "$_bp/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && source "$_bp/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  unset _bp
else
  [ -s /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  [ -s /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# starship prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# fzf key-bindings (ctrl+r history search)
if __is_macos && command -v brew >/dev/null 2>&1; then
  _fzf_keys="$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  _fzf_keys="/usr/share/doc/fzf/examples/key-bindings.zsh"
fi
[[ -n "$_fzf_keys" && -s "$_fzf_keys" ]] && source "$_fzf_keys"
unset _fzf_keys
