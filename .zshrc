# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
[ -f ~/.zsh_prompt ] && source ~/.zsh_prompt

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=910000
SAVEHIST=910000
setopt appendhistory autocd extendedglob
setopt No_Beep
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/miguel/.zshrc'


# tab completion
autoload -Uz compinit
compinit
# End of lines added by compinstall

umask 002
ulimit -c unlimited

export TERM="xterm-256color"

IRCNAME="More human than human"
IRCUSER="brainstorm"
IRCNICK="m3thos"
EDITOR="vim"

export IRCSERVER IRCNAME IRCUSER IRCNICK EDITOR
# aliases for all shell's

alias ls="ls -G -Fv --color"
alias l='ls -G --color'
alias rm='\rm -i'
alias la='ls -a --color'
alias ll='ls -aihlrt --color'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'
alias view='vim -R'
alias grep='grep --color'
alias less='less -RSXF'
alias lock='gnome-screensaver-command -l'
alias j='jobs'
alias ipython='ipython3'
alias term='xterm +sb -sl 5000 -bg black -fg grey -fa Monospace -fs 10 -u8'
alias dstat='dstat -c -r -d -n -m -s -y --nocolor'
alias vvac="python3 -m venv env && source env/bin/activate && pip install --upgrade pip"
alias vac="source env/bin/activate"
alias gti=git
alias tmux="tmux -2"
alias k="kubectl"
alias swagger='docker run --rm -it  --user $(id -u):$(id -g) -e GOPATH=$(go env GOPATH):/go -v $HOME:$HOME -w $(pwd) quay.io/goswagger/swagger'
alias rp="rocketpool"
alias snip='grim -g "$(slurp)" - | wl-copy'
#alias docker="podman"

# keychain
keychain=`which keychain`
if [ -x ${keychain} ]; then
    ${keychain} -q ~/.ssh/id_ed25519
    source ~/.keychain/${HOST}-sh  > /dev/null
fi


[ -d ~/bin ] && PATH="${HOME}/bin:${PATH}"
PATH="/sbin:/usr/sbin:${PATH}"
PATH="/snap/bin:${PATH}"
PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
PATH="/usr/local/go/bin:${PATH}"
GOPATH="${HOME}/go"
PATH="${GOPATH}/bin:${PATH}"
PATH="/opt/homebrew/bin/:$PATH"
PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
export PATH CLASSPATH GOPATH
export GOPRIVATE="github.com/duneanalytics"
export GIT_TERMINAL_PROMPT=1

# kubectl
kubectl=`which kubectl`
if [ -x ${kubectl} ]; then
    source <(kubectl completion zsh)
fi

# for rust
[ -f $HOME/.cargo/env ] && . "$HOME/.cargo/env"

# pyenv
pyenv=`which pyenv`
if [ -x ${pyenv} ]; then
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

# zprezto
#[ -d ~/.zprezto ] && source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"

[ -f ~/.zshrc_private ] && source ~/.zshrc_private

# for alacritty
fpath+=${ZDOTDIR:-~}/.zsh_functions

#  export NVM_DIR="$HOME/.nvm"
#  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
#  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


