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
alias gvim='gvim 2>/dev/null' #gvim is printing asserts to stderr, dirties the console.
alias lock='gnome-screensaver-command -l'
alias j='jobs'
alias term='xterm -bg black -fg grey -fa Monospace -fs 9 -u8'
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
alias sapo-vpn='sudo pppd call VPN-W'
alias mpirun='mpirun --mca mpi_paffinity_alone 1'
alias sshfs='sshfs -o reconnect,intr'

# keychain
keychain=`which keychain`
if [ -x ${keychain} ]; then
    ${keychain} -q ~/.ssh/id_rsa
    source ~/.keychain/${HOST}-sh  > /dev/null
fi



[ -d ~/bin ] && PATH="${HOME}/bin:${PATH}"

PATH="${PATH}:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
#PATH="${PATH}:/opt/j2sdk1.4.1/jre/bin:/opt/j2sdk1.4.1/bin"
#CLASSPATH="/usr/share/junit/lib/junit.jar:${CLASSPATH}"
PYTHONPATH="${HOME}/sapo/libsapo-broker-python/:${HOME}/code/pysmell:.:${HOME}/sapo/v3.git/trunk/sawpy/py-libsaw:${HOME}/sapo/"
LD_LIBRARY_PATH=${HOME}/sapo/v3.trunk/.build/default/libsaw
export PATH CLASSPATH PYTHONPATH LD_LIBRARY_PATH
