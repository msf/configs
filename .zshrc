# History
HISTFILE=$HOME/.histfile
HISTSIZE=910000
SAVEHIST=910000
setopt appendhistory autocd extendedglob histignorealldups sharehistory no_beep
bindkey -e

# Completion
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

umask 002
export EDITOR=nvim
export LESS=-X

# Aliases
alias vim='nvim'
alias vimdiff='nvim -d'
if [[ $OSTYPE == darwin* ]]; then
  alias nix-rebuild='sudo darwin-rebuild switch --flake ~/configs/macos\#liskov'
  alias linux='limactl shell linux-dev'
  alias shlinux='limactl shell linux-dev'
  # Node comes from Nix (read-only); global npm packages (pi, codex) go to ~/.local
  export NPM_CONFIG_PREFIX=$HOME/.local
  alias ls='ls -GFv'
  alias l='ls -G'
  alias la='ls -aG'
  alias ll='ls -aihlrtG'
else
  alias ls='ls -Fv --color=auto'
  alias l='ls --color=auto'
  alias la='ls -a --color=auto'
  alias ll='ls -aihlrt --color=auto'
fi
alias rm='\rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'
alias grep='grep --color=auto'
alias lock='gnome-screensaver-command -l'
alias j='jobs'
alias ipy='ipython3'
alias dstat='dstat -c -r -d -n -m -s -y --nocolor'
alias vvac='python3 -m venv env && source env/bin/activate && pip install --upgrade pip'
alias vac='source env/bin/activate'
alias gti=git
alias tmux='tmux -2'
alias k=kubectl
alias rp=rocketpool
alias snip='grim -g "$(slurp)" - | wl-copy'
alias pip=pip3
alias python=python3
alias py=python3
alias lsof='lsof -n -M'
alias day='gsettings set org.gnome.desktop.interface color-scheme prefer-light'
alias night='gsettings set org.gnome.desktop.interface color-scheme prefer-dark'


# for sway
export XKB_DEFAULT_OPTIONS=caps:ctrl
# firefox on wayland
export MOZ_ENABLE_WAYLAND=1

# Environment
export KUBECONFIG=$HOME/.kube/config
export PYENV_ROOT=$HOME/.pyenv
export SDKMAN_DIR=$HOME/.sdkman
export WASMER_DIR=$HOME/.wasmer
export WASMER_CACHE_DIR=$WASMER_DIR/cache
export WASMTIME_HOME=$HOME/.wasmtime
export BUN_INSTALL=$HOME/.bun

typeset -U path PATH
path=(
  $HOME/bin
  $HOME/.local/bin
  $HOME/.local/share/pi-node/current/bin
  $HOME/go/bin
  $HOME/.cargo/bin
  $HOME/.fzf/bin
  $PYENV_ROOT/bin
  $PYENV_ROOT/shims
  $HOME/.tiup/bin
  $HOME/.wasmer/bin
  $WASMTIME_HOME/bin
  $HOME/.opencode/bin
  $BUN_INSTALL/bin
  $HOME/.yarn/bin
  /snap/bin
  /opt/homebrew/opt/llvm@19/bin
  /opt/homebrew/opt/coreutils/libexec/gnubin
  /opt/homebrew/bin
  /usr/local/go/bin
  /usr/local/bin
  /usr/local/sbin
  /sbin
  /usr/sbin
  /opt/nvim/bin
  $path
)

if (( $+commands[keychain] )); then
  keychain -q $HOME/.ssh/id_ed25519
  keychain_file=$HOME/.keychain/${HOST}-sh
  [[ -r $keychain_file ]] && source $keychain_file
  unset keychain_file
fi

if (( $+commands[kubectl] )); then
  _kubectl() {
    unfunction _kubectl
    source <(kubectl completion zsh)
    _kubectl "$@"
  }
  compdef _kubectl kubectl k
fi

(( $+commands[pyenv] )) && eval "$(pyenv init -)"

if [[ -s $SDKMAN_DIR/bin/sdkman-init.sh ]]; then
  path=($SDKMAN_DIR/candidates/*/current/bin(N) $path)
  sdk() {
    unfunction sdk
    source $SDKMAN_DIR/bin/sdkman-init.sh
    sdk "$@"
  }
fi

[[ -f $HOME/.zshrc_private ]] && source $HOME/.zshrc_private

(( $+commands[direnv] )) && eval "$(direnv hook zsh)"
[[ -t 0 && -t 1 ]] && (( $+commands[fzf] )) && source <(fzf --zsh)
[[ -f $HOME/.zsh_prompt ]] && source $HOME/.zsh_prompt

export NVM_DIR=$HOME/.nvm
if [[ -s $NVM_DIR/nvm.sh ]]; then
  source $NVM_DIR/nvm.sh --no-use
  node_version=$(nvm version default)
  if [[ $node_version != N/A ]]; then
    export NVM_BIN=$NVM_DIR/versions/node/$node_version/bin
    path=($NVM_BIN $path)
  fi
  unset node_version
fi

# >>> railway initialize >>>
[[ -r "$HOME/.railway/env" ]] && source "$HOME/.railway/env"
# <<< railway initialize <<<
