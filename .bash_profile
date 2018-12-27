#!/bin/bash
# ~/.bash_profile: executed by bash(1) for login shells.
# see /usr/share/doc/bash/examples/startup-files for examples

HISTSIZE=10000
HISTFILESIZE=10000
export HISTSIZE HISTFILESIZE


EDITOR=vim
export EDITOR

# keychain
keychain=`which keychain`
if [ -x ${keychain} ]; then
    ${keychain} -q ~/.ssh/id_rsa
    source ~/.keychain/${HOSTNAME}-sh  > /dev/null
fi

# include .bashrc if it exists
[ -f ~/.bashrc ] && source ~/.bashrc

# set PATH so it includes user's private bin if it exists
[ -d ${HOME}/bin ] && PATH="${PATH}:${HOME}/bin"


export LD_LIBRARY_PATH="/home/miguel/sapo/v3.git/trunk/.build/default/libsaw:/opt/lxc/lib"
PATH="${PATH}:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
PATH="${PATH}:/opt/lxc/bin"
#PATH="${PATH}:/opt/j2sdk1.4.1/jre/bin:/opt/j2sdk1.4.1/bin"
#CLASSPATH="/usr/share/junit/lib/junit.jar:${CLASSPATH}"
PYTHONPATH="${HOME}/sapo/v3.git/trunk/sawpy/py-libsaw:${HOME}/sapo/v3.git/sawpy/py-libsaw:${HOME}/sapo/libsapo-broker-python"

export PATH CLASSPATH PYTHONPATH

export PATH="$HOME/.cargo/bin:$PATH"
