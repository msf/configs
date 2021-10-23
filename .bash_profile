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
