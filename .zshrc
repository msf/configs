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
alias term='xterm -bg black -fg grey -fa Monospace -fs 9 -u8'
#pacman/arch stuff
alias pacget='sudo pacman -S'
alias pacls='sudo pacman -Ss'
alias pacup='sudo pacman -Syu'

# keychain
if [ -x /usr/bin/keychain ]; then
    /usr/bin/keychain -q ~/.ssh/id_rsa
    source ~/.keychain/${HOST}-sh  > /dev/null
fi


[ -f ~/.prompt_zsh ] && source ~/.prompt_zsh


if [ -d ~/bin ] ; then
    PATH="~/bin:${PATH}"
fi
PATH="${PATH}:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
#PATH="${PATH}:/opt/j2sdk1.4.1/jre/bin:/opt/j2sdk1.4.1/bin"
#CLASSPATH="/usr/share/junit/lib/junit.jar:${CLASSPATH}"
PYTHONPATH="${HOME}/work/libsapo-broker-python/:${HOME}/code/pysmell:.:${HOME}/work/v3.git/sawpy/py-libsaw/"

export PATH CLASSPATH PYTHONPATH
