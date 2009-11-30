# ~/.bash_profile: executed by bash(1) for login shells.
# see /usr/share/doc/bash/examples/startup-files for examples

umask 022

ulimit -c unlimited

HISTSIZE=10000
HISTFILESIZE=10000
export HISTSIZE HISTFILESIZE


EDITOR=vim
export EDITOR

# keychain
if [ -x /usr/bin/keychain ]; then
    /usr/bin/keychain -q ~/.ssh/id_rsa
    source ~/.keychain/${HOSTNAME}-sh  > /dev/null
fi

# include .bashrc if it exists
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# set PATH so it includes user's private bin if it exists

if [ -d ~/bin ] ; then
    PATH="~/bin:${PATH}"
fi
PATH="${PATH}:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
#PATH="${PATH}:/opt/j2sdk1.4.1/jre/bin:/opt/j2sdk1.4.1/bin"
#CLASSPATH="/usr/share/junit/lib/junit.jar:${CLASSPATH}"
PYTHONPATH="${HOME}/work/libsapo-broker-python/:${HOME}/code/pysmell:.:${HOME}/work/v3.git/sawpy/py-libsaw/"

export PATH CLASSPATH PYTHONPATH


