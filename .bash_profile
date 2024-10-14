#!/bin/bash
# ~/.bash_profile: executed by bash(1) for login shells.
# see /usr/share/doc/bash/examples/startup-files for examples

HISTSIZE=10000
HISTFILESIZE=10000
export HISTSIZE HISTFILESIZE


EDITOR=vim
export EDITOR

# include .bashrc if it exists
[ -f ~/.bashrc ] && source ~/.bashrc

# set PATH so it includes user's private bin if it exists
[ -d ${HOME}/bin ] && PATH="${PATH}:${HOME}/bin"


PATH="${PATH}:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
PATH="${PATH}:/opt/lxc/bin"

export PATH
. "$HOME/.cargo/env"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/miguel/.sdkman"
[[ -s "/Users/miguel/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/miguel/.sdkman/bin/sdkman-init.sh"
