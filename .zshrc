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
alias gvim='gvim 2>/dev/null' #gvim is printing asserts to stderr, dirties the console.
alias lock='gnome-screensaver-command -l'
alias google-chrome='google-chrome --enable-plugins'
alias j='jobs'
alias ipy='ipython -nobanner -noconfirm_exit'
alias term='xterm +sb -sl 5000 -bg black -fg grey -fa Monospace -fs 10 -u8'
alias eve='wine explorer /desktop=0,1680x1050 "C:\Program Files\CCP\EVE\bin\exefile.exe'
alias ventrilo='wine ~/.wine/drive_c/Program\ Files/Ventrilo/Ventrilo.exe'
alias dstat='dstat -c -d -n -m -s -y'
#pacman/arch stuff
alias pacget='sudo pacman -S'
alias pacls='sudo pacman -Ss'
alias pacup='sudo pacman -Syu'
alias pacrm='sudo pacman -R'
alias pacup2='yaourt -Syu --aur'
alias aptls='aptitude search'
alias aptget='sudo aptitude install'
alias aptls='aptitude search'
alias aptrm='sudo aptitude remove'
alias aptup='sudo aptitude update && sudo aptitude upgrade'
alias sapo-vpn='sudo pppd call VPN-W'
alias mpirun='mpirun --mca mpi_paffinity_alone 1'
alias sshfs='sshfs -o reconnect,intr'
alias pr="hub pull-request"
alias vac="source env/bin/activate"
alias gti=git

# keychain
keychain=`which keychain`
if [ -x ${keychain} ]; then
    ${keychain} -q ~/.ssh/id_rsa
    source ~/.keychain/${HOST}-sh  > /dev/null
fi


[ -f ~/.prompt_zsh ] && source ~/.prompt_zsh

[ -d ~/bin ] && PATH="${HOME}/bin:${PATH}"

PATH="${PATH}:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
#PATH="${PATH}:/opt/j2sdk1.4.1/jre/bin:/opt/j2sdk1.4.1/bin"
#CLASSPATH="/usr/share/junit/lib/junit.jar:${CLASSPATH}"
PYTHONPATH="."
#export LD_LIBRARY_PATH=
GOPATH="${HOME}/go"
PATH="${GOPATH}/bin:${PATH}:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
export PATH CLASSPATH PYTHONPATH GOPATH
