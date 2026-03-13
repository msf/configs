
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=910000
SAVEHIST=910000

setopt appendhistory autocd extendedglob
setopt histignorealldups sharehistory
setopt No_Beep
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/miguel/.zshrc'


# tab completion
autoload -Uz compinit
compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
# eval "$(dircolors -b)"  # not available on macOS
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
# End of lines added by compinstall

umask 002
ulimit -c unlimited

export TERM="xterm-256color"

IRCNAME="More human than human"
IRCUSER="brainstorm"
IRCNICK="m3thos"
EDITOR="nvim"
#PAGER="vimpager"
export LESS=-X

export IRCSERVER IRCNAME IRCUSER IRCNICK EDITOR

# aliases for all shell's
alias vim="nvim"
alias vimdiff="nvim -d"
alias ls="ls -G -Fv --color"
alias l='ls -G --color'
alias rm='\rm -i'
alias la='ls -a --color'
alias ll='ls -aihlrt --color'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'
alias grep='grep --color'
#alias less='less -RSXF'
alias lock='gnome-screensaver-command -l'
alias j='jobs'
alias ipy='ipython3'
alias dstat='dstat -c -r -d -n -m -s -y --nocolor'
alias vvac="python3 -m venv env && source env/bin/activate && pip install --upgrade pip"
alias vac="source env/bin/activate"
alias gti=git
alias tmux="tmux -2"
alias k="kubectl"
alias rp="rocketpool"
alias snip='grim -g "$(slurp)" - | wl-copy'
alias pip="pip3"
alias python="python3"
alias py="python3"
alias lsof="lsof -n -M"  # don't resolve names nor ports
#alias docker="podman"
#alias sudo="doas"
alias opencode='AWS_PROFILE=default AWS_REGION=eu-west-1 $HOME/.opencode/bin/opencode'


# for sway
export XKB_DEFAULT_OPTIONS=caps:ctrl
# firefox on wayland
export MOZ_ENABLE_WAYLAND=1

# keychain
keychain=`which keychain`
if [ -x ${keychain} ]; then
    ${keychain} -q ~/.ssh/id_ed25519
    ${keychain} -q ~/.ssh/miguel_dune
    source ~/.keychain/${HOST}-sh  > /dev/null
fi

PATH="/sbin:/usr/sbin:${PATH}"
PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
PATH="/usr/local/go/bin:${PATH}"
PATH="/opt/homebrew/bin/:$PATH"
PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
[ -d /snap/bin ] && PATH="/snap/bin:${PATH}"
[ -d ~/.yarn/bin ] && PATH="${HOME}/.yarn/bin:${PATH}"
[ -d ~/.local/bin ] && PATH="${HOME}/.local/bin:${PATH}"
[ -d ~/bin ] && PATH="${HOME}/bin:${PATH}"
[ -d ~/go/bin ] && PATH="${HOME}/go/bin:${PATH}"
PATH="$PATH:/opt/nvim-linux-x86_64/bin"
PATH="/opt/homebrew/opt/llvm@19/bin:${PATH}"
export PATH CLASSPATH
export PATH=/home/miguel/.tiup/bin:$PATH
export GOPRIVATE="github.com/duneanalytics"
export GIT_TERMINAL_PROMPT=1

# kubectl
kubectl=`which kubectl`
if [ -x ${kubectl} ]; then
    source <(kubectl completion zsh)
fi
export KUBECONFIG=/home/miguel/.kube/config

# for rust
[ -f $HOME/.cargo/env ] && . "$HOME/.cargo/env"

# python stuff
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH" && eval "$(pyenv init -)"

# java stuff
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

[ -f ~/.zshrc_private ] && source ~/.zshrc_private

function dpsql {
	PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id ${1}_${2}_db_${2}_user_password --output text --query SecretString) psql -U ${2} -h ${1}-${2}-db ${2}
}

# dbsh <env> <service> [dbname]
# Connects read-only: prefers -db-rr host, falls back to primary;
# prefers readonly credentials from Secrets Manager, falls back to service user.
function dbsh {
  local env="${1}" svc="${2}" db="${3:-${2}}"

  if [[ -z "$env" || -z "$svc" ]]; then
    echo "usage: dbsh <env> <service> [dbname]" >&2
    return 1
  fi

  # Prefer read replica in Tailscale, fall back to primary
  local rr_host="${env}-${svc}-db-rr"
  local host
  if tailscale status 2>/dev/null | grep "  ${rr_host}  " | grep -qv "offline"; then
    host="$rr_host"
  else
    host="${env}-${svc}-db"
  fi

  # Prefer readonly secret, fall back to service-user secret
  local secret_ro="${env}_${svc}_db_readonly_user_secret"
  local secret user
  if aws secretsmanager describe-secret --secret-id "$secret_ro" &>/dev/null; then
    secret="$secret_ro"
    user="readonly"
  else
    secret="${env}_${svc}_db_${svc}_user_password"
    user="$svc"
  fi

  local password
  password=$(aws secretsmanager get-secret-value --secret-id "$secret" --query SecretString --output text 2>/dev/null)
  if [[ -z "$password" ]]; then
    echo "error: could not retrieve secret '$secret'" >&2
    return 1
  fi

  echo "→ host=${host}  user=${user}  secret=${secret}" >&2
  PGPASSWORD="$password" psql -U "$user" -h "$host" "$db"
}

# fzf, manual install
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

[ -f ~/.zsh_prompt ] && source ~/.zsh_prompt


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Wasmer
export WASMER_DIR="/home/miguel/.wasmer"
[ -s "$WASMER_DIR/wasmer.sh" ] && source "$WASMER_DIR/wasmer.sh"
export WASMTIME_HOME="$HOME/.wasmtime"
export PATH="$WASMTIME_HOME/bin:$PATH"
. "/home/miguel/.wasmedge/env"

# opencode
export PATH=/home/miguel/.opencode/bin:$PATH
