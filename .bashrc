# @(#)bashrc 2001/03/22
umask 007


IRCNAME="More human than human"
IRCUSER="brainstorm"
IRCNICK="m3thos"
export IRCNAME IRCUSER IRCNICK

# aliases for all shell's
alias ls="ls --color=auto"
alias l='ls -F'
alias rm='\rm -i'
alias la='ls -aF'
alias ll='ls -ihlF'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'
alias view='vim -R'
alias grep='grep --color'
alias lock='gnome-screensaver-command -l'
alias j='jobs'
alias lbuild=" LOCAL_SOURCES=1 ADWORDS_DEBUG=1 ./build "
alias mysql1='mysql -h adw-sql1 -u adwords -p adwords'
alias mysql2='mysql -h adw-sql2 -u adwords -p adwords'
alias term='xterm -bg black -fg grey -fa Monospace -fs 9 -u8'
alias dhead='xrandr --output VGA --right-of LVDS'
alias thead='pkill synergys && synergys && ssh tmig "pkill synergyc && synergyc preto"'
alias ipy='ipython -nobanner -noconfirm_exit'
alias ack='ack-grep'
alias dstat='dstat -c -d -n -m -s -y'
#pacman/arch stuff
alias pacget='sudo pacman -S'
alias pacls='sudo pacman -Ss'
alias pacup='sudo pacman -Syu'
alias aptget='sudo aptitude install'
alias aptls='aptitude search'
alias aptrm='sudo aptitude remove'
alias aptup='sudo aptitude update && sudo aptitude upgrade'


function dsh() {
    dssh -F 4 -W $*
}


# carregar prompt bonita
[ -f ~/.prompt_bash ] && source ~/.prompt_bash

##uncomment the following to activate bash-completion:
[ -f /etc/profile.d/bash-completion ] && source /etc/profile.d/bash-completion

#--[EOF]--
