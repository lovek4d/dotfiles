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

# brew prefix — resolved once, reused throughout
(( $+commands[brew] )) && _BREW_PFX=$(brew --prefix)

# autocomplete (must be before sourcing files that use compdef)
if [[ -n "${_BREW_PFX:-}" ]]; then
  FPATH="$_BREW_PFX/share/zsh/site-functions:${FPATH}"
fi
if [[ -d /usr/share/zsh/vendor-completions ]]; then
  FPATH="/usr/share/zsh/vendor-completions:${FPATH}"
fi
autoload -Uz promptinit && promptinit
autoload -Uz compinit && compinit

# fzf base wrapper
__fzf() { fzf --height=40% --reverse --no-sort "$@"; }

# source others
source $HOME/dev/dotfiles/zshrc/git.zsh
source $HOME/dev/dotfiles/zshrc/tmux.zsh
source $HOME/dev/dotfiles/zshrc/tailscale.zsh
source $HOME/dev/dotfiles/zshrc/funcs.zsh
source $HOME/dev/dotfiles/zshrc/claude.zsh
source $HOME/dev/dotfiles/zshrc/vim.zsh
source $HOME/dev/dotfiles/zshrc/ssh.zsh
source $HOME/dev/dotfiles/zshrc/docker.zsh
source $HOME/dev/dotfiles/zshrc/whisper.zsh

# machine-local extensions (gitignored — add .zsh files to zshrc/local/)
for _f in $HOME/dev/dotfiles/zshrc/local/*.zsh(N); do source "$_f"; done
unset _f

# general
z() {
  cat <<'EOF'
zshrc aliases:
  general
    dev          cd ~/dev
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
  local
    zshrc/local/*.zsh  machine-specific extensions (gitignored)
  help
    c      claude aliases
    d      docker aliases
    g      git aliases
    s      ssh aliases
    tm     tmux aliases
    ts     tailscale aliases
    v      vim aliases
    w      whisper aliases
EOF
}

# bootstrap
zinit() {
  local pkgs=(git fzf tmux vim python3 zsh-autosuggestions zsh-syntax-highlighting zoxide)

  if __is_macos; then
    _zinit_macos "${pkgs[@]}" nvm claude-code colima docker starship tailscale
  elif __is_linux; then
    _zinit_linux "${pkgs[@]}" zsh curl xclip docker.io
  else
    echo "unsupported platform: $OSTYPE" && return 1
  fi

  echo "=== git ==="
  ginit

  echo "=== tmux ==="
  tminit

  echo "=== starship ==="
  mkdir -p "$HOME/.config"
  ln -sf "$HOME/dev/dotfiles/configs/starship.toml" "$HOME/.config/starship.toml"
  echo "symlinked ~/dev/dotfiles/configs/starship.toml → ~/.config/starship.toml"

  echo "=== ssh ==="
  sinit

  echo "=== claude ==="
  cinit

  echo "=== done ==="
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
  sudo apt install -y "$@"

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

# sudo (trailing space expands aliases after sudo)
alias sudo='sudo '

# python basics
alias python='python3'
alias wdvenv='source .venv/bin/activate'

# nvm + autocomplete
export NVM_DIR="$HOME/.nvm"
if [[ -n "${_BREW_PFX:-}" ]]; then
  [ -s "$_BREW_PFX/opt/nvm/nvm.sh" ] && \. "$_BREW_PFX/opt/nvm/nvm.sh"
  [ -s "$_BREW_PFX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$_BREW_PFX/opt/nvm/etc/bash_completion.d/nvm"
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

# brew shell env (inlined from brew shellenv, no subprocess)
if [[ -n "${_BREW_PFX:-}" ]]; then
  export HOMEBREW_PREFIX="$_BREW_PFX"
  export HOMEBREW_CELLAR="$_BREW_PFX/Cellar"
  export HOMEBREW_REPOSITORY="$_BREW_PFX"
  path=("$_BREW_PFX/bin" "$_BREW_PFX/sbin" $path)
  export MANPATH="$_BREW_PFX/share/man${MANPATH+:$MANPATH}:"
  export INFOPATH="$_BREW_PFX/share/info:${INFOPATH:-}"
fi

# zoxide (j/ji)
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd j)"

# zsh plugins (syntax-highlighting must be last)
if [[ -n "${_BREW_PFX:-}" ]]; then
  [ -s "$_BREW_PFX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && source "$_BREW_PFX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [ -s "$_BREW_PFX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && source "$_BREW_PFX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
  [ -s /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  [ -s /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# starship prompt
(( $+commands[starship] )) && eval "$(starship init zsh)"

# fzf key-bindings (ctrl+r history search)
if [[ -n "${_BREW_PFX:-}" ]]; then
  _fzf_keys="$_BREW_PFX/opt/fzf/shell/key-bindings.zsh"
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  _fzf_keys="/usr/share/doc/fzf/examples/key-bindings.zsh"
fi
[[ -n "$_fzf_keys" && -s "$_fzf_keys" ]] && source "$_fzf_keys"
unset _fzf_keys _BREW_PFX
