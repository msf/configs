# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory autocd extendedglob
setopt No_Beep
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/miguel/.zshrc'


autoload -Uz compinit
compinit
# End of lines added by compinstall

umask 007


IRCSERVER=netcabo.ptnet.org
IRCNAME="More human than human"
IRCUSER="brainstorm"
IRCNICK="m3thos"

export IRCSERVER IRCNAME IRCUSER IRCNICK PS1
# aliases for all shell's

alias ls="ls --color=auto"
alias l='ls -F'
alias rm='\rm -i'
alias la='ls -aF'
alias ll='ls -aihlF'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'
alias view='vim -R'
alias grep='grep --color'
alias lock='gnome-screensaver-command -l'
alias google-chrome='google-chrome --enable-plugins'


[ -f ~/.prompt_zsh ] && source ~/.prompt_zsh
