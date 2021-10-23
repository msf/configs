# @(#)bashrc 2001/03/22

umask 027

ulimit -c unlimited

IRCNAME="More human than human"
IRCUSER="brainstorm"
IRCNICK="m3thos"
EDITOR="vim"

export IRCSERVER IRCNAME IRCUSER IRCNICK EDITOR
# aliases for all shell's

alias ls="ls -G -Fv"
alias l='ls -G'
alias rm='\rm -i'
alias la='ls -a'
alias ll='ls -aihlrt'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'
alias view='vim -R'
alias grep='grep --color'
alias less='less -RSXF'
alias lock='gnome-screensaver-command -l'
alias j='jobs'
alias term='xterm -bg black -fg grey -fa Monospace -fs 9 -u8'
alias ipy='ipython -nobanner -noconfirm_exit'
alias ack='ack-grep'
alias dstat='dstat -c -d -n -m -s -y'
alias vac="source env/bin/activate"


[ -d ~/bin ] && PATH="${HOME}/bin:${PATH}"

PATH="${PATH}:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
GOPATH="${HOME}/go"
export PATH GOPATH
. "$HOME/.cargo/env"
