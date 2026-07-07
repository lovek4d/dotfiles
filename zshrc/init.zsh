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
source $HOME/dev/dotfiles/zshrc/agent-worktree.zsh
source $HOME/dev/dotfiles/zshrc/tailscale.zsh
source $HOME/dev/dotfiles/zshrc/funcs.zsh
source $HOME/dev/dotfiles/zshrc/claude.zsh
source $HOME/dev/dotfiles/zshrc/codex.zsh
source $HOME/dev/dotfiles/zshrc/vim.zsh
source $HOME/dev/dotfiles/zshrc/ssh.zsh
source $HOME/dev/dotfiles/zshrc/docker.zsh
source $HOME/dev/dotfiles/zshrc/whisper.zsh
source $HOME/dev/dotfiles/zshrc/bootstrap.zsh

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
    ainit  agent settings + optional skills/plugins
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
  helpers
    rg <pat>     ripgrep (fast grep, respects .gitignore)
    fd <pat>     find replacement
    bat <file>   cat with syntax highlight
    fzf          fuzzy finder (ctrl+r history)
    jq <expr>    JSON query
    sd <p> <r>   sed replacement
    tldr <cmd>   community cheatsheets
    starship     prompt (auto)
    zoxide       j/ji directory jump
  help
    c      claude aliases
    co     codex aliases
    d      docker aliases
    g      git aliases
    s      ssh aliases
    tm     tmux aliases
    ts     tailscale aliases
    v      vim aliases
    w      whisper aliases
EOF
}

# nav basics
alias dev='cd ~/dev'
mkcd() { mkdir -p "$1" && cd "$1"; }

# linux apt ships fd/bat under different binary names
if __is_linux; then
  (( $+commands[fdfind] )) && alias fd='fdfind'
  (( $+commands[batcat] )) && alias bat='batcat'
fi

# sudo (trailing space expands aliases after sudo)
alias sudo='sudo '

# python basics
alias python='python3'
alias wdvenv='source .venv/bin/activate'

# nvm + autocomplete
__load_nvm
if [[ -n "${_BREW_PFX:-}" ]]; then
  [ -s "$_BREW_PFX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$_BREW_PFX/opt/nvm/etc/bash_completion.d/nvm"
else
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

# claude native installer drops binary here
path=("$HOME/.local/bin" $path)

# zoxide (j/ji)
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd j)"

# starship prompt
(( $+commands[starship] )) && eval "$(starship init zsh)"

# fzf key-bindings (ctrl+r history search)
if [[ -n "${_BREW_PFX:-}" ]]; then
  _fzf_keys="$_BREW_PFX/opt/fzf/shell/key-bindings.zsh"
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  _fzf_keys="/usr/share/doc/fzf/examples/key-bindings.zsh"
fi
[[ -n "$_fzf_keys" && -s "$_fzf_keys" ]] && source "$_fzf_keys"
unset _fzf_keys

# zsh plugins — must come after all widget/hook setup above.
# syntax-highlighting must be the absolute last plugin sourced.
if [[ -n "${_BREW_PFX:-}" ]]; then
  [ -s "$_BREW_PFX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && source "$_BREW_PFX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [ -s "$_BREW_PFX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && source "$_BREW_PFX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
  [ -s /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  [ -s /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
unset _BREW_PFX
