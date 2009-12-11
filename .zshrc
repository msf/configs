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

umask 027
ulimit -c unlimited


IRCNAME="More human than human"
IRCUSER="brainstorm"
IRCNICK="m3thos"
EDITOR="vim"

export IRCSERVER IRCNAME IRCUSER IRCNICK EDITOR
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
alias ipy='ipython -nobanner -noconfirm_exit'
alias term='xterm +sb -sl 5000 -bg black -fg grey -fa Monospace -fs 10 -u8'
alias eve='wine explorer /desktop=0,1680x1050 "C:\Program Files\CCP\EVE\eve.exe"'
#pacman/arch stuff
alias pacget='sudo pacman -S'
alias pacls='sudo pacman -Ss'
alias pacup='sudo pacman -Syu'
alias pacrm='sudo pacman -R'
alias pacup2='yaourt -Syu --aur'
alias aptls='aptitude search'
alias aptget='sudo aptitude install'
alias aptup='sudo aptitude update; sudo aptitude safe-upgrade'
alias aptrm='sudo aptitude remove'
alias rdpvivo='rdesktop -g 1024x768 -z -x m -P elchapelon.no-ip.info:8888 &'

# keychain
if [ -x /usr/bin/keychain ]; then
    /usr/bin/keychain -q ~/.ssh/id_rsa
    source ~/.keychain/${HOST}-sh  > /dev/null
fi


[ -f ~/.prompt_zsh ] && source ~/.prompt_zsh

[ -d ~/bin ] && PATH="${HOME}/bin:${PATH}"

PATH="${PATH}:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
#PATH="${PATH}:/opt/j2sdk1.4.1/jre/bin:/opt/j2sdk1.4.1/bin"
#CLASSPATH="/usr/share/junit/lib/junit.jar:${CLASSPATH}"
PYTHONPATH="${HOME}/work/libsapo-broker-python/:${HOME}/code/pysmell:.:${HOME}/work/v3.git/sawpy/py-libsaw/"

export PATH CLASSPATH PYTHONPATH
