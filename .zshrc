# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
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

umask 027
ulimit -c unlimited


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
alias ipy='ipython -nobanner -noconfirm_exit'
alias term='xterm +sb -sl 5000 -bg black -fg grey -fa Monospace -fs 10 -u8'
alias dstat='dstat -c -r -d -n -m -s -y'
alias vvac="python3 -m venv env && source env/bin/activate && pip install --upgrade pip"
alias vac="source env/bin/activate"
alias gti=git
alias tmux="tmux -2"
alias k="kubectl"
alias docker="podman"

# keychain
keychain=`which keychain`
if [ -x ${keychain} ]; then
    ${keychain} -q ~/.ssh/id_rsa
    ${keychain} -q ~/.ssh/id_ed25519
    source ~/.keychain/${HOST}-sh  > /dev/null
fi


[ -d ~/bin ] && PATH="${HOME}/bin:${PATH}"


PATH="/sbin:/usr/sbin:${PATH}"
PATH="/snap/bin:${PATH}"
PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
PATH="/opt/go/bin:${PATH}"
GOPATH="${HOME}/go"
PATH="${GOPATH}/bin:${PATH}"
PATH=$PATH:/snap/bin
export PATH CLASSPATH GOPATH
export GOPRIVATE="gitlab.com/Unbabel"


# kubectl
kubectl=`which kubectl`
if [ -x ${kubectl} ]; then
    source <(kubectl completion zsh)
fi

# zprezto
#[ -d ~/.zprezto ] && source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"

[ -f ~/.zshrc_private ] && source ~/.zshrc_private

[ -f ~/.prompt_zsh ] && source ~/.prompt_zsh
#source  ~/powerlevel9k/powerlevel9k.zsh-theme

# for alacritty
fpath+=${ZDOTDIR:-~}/.zsh_functions
