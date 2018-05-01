# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=/Users/miguel/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="pygmalion"
ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git python brew pip)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export DEFAULT_USER="miguel"
#
#
################### MY STUFF
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
alias aptls='aptitude search'
alias aptget='sudo aptitude install'
alias aptls='aptitude search'
alias aptrm='sudo aptitude remove'
alias aptup='sudo aptitude update && sudo aptitude upgrade'
alias mpirun='mpirun --mca mpi_paffinity_alone 1'
alias sshfs='sshfs -o reconnect,intr'
alias pr="hub pull-request"
alias vac="source env/bin/activate"
alias va3="source venv/bin/activate"
alias gti=git
alias frp="python -m icecastle.region_party"
alias cm-ops="cd ~/cm/operations ; source env/bin/activate"
alias tmux='tmux -2'  # use 256 colors


# keychain
keychain=`which keychain`
if [ -x ${keychain} ]; then
    ${keychain} -q ~/.ssh/id_rsa
    ${keychain} -q ~/.ssh/payments-miguel-ssh-keyfile.pem
    source ~/.keychain/${HOST}-sh  > /dev/null
fi

if [ -x `which nvim` ]; then
    alias vim=nvim
fi

# [ -f ~/.prompt_zsh ] && source ~/.prompt_zsh

[ -d ~/bin ] && PATH="${HOME}/bin:${PATH}"


function fssh() {
    instance="$1"
    if [[ $instance =~ ^i- ]]
    then
        fab zone:b iid:$@ ssh
    else
        fab zone:b group:$@ most_recent ssh
    fi
}

PATH="/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:${PATH}"
#PATH="${PATH}:/opt/j2sdk1.4.1/jre/bin:/opt/j2sdk1.4.1/bin"
#CLASSPATH="/usr/share/junit/lib/junit.jar:${CLASSPATH}"
PYTHONPATH="."
#export LD_LIBRARY_PATH=
GOPATH="${HOME}/go"
PATH="${GOPATH}/bin:${PATH}"
PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:${PATH}"
export PATH CLASSPATH PYTHONPATH GOPATH

export SERVER_RESOURCES_DIR="${HOME}/cm/static-config/server_resources/staging"

# The next line updates PATH for the Google Cloud SDK.
if [ -f /Users/miguel/Downloads/google-cloud-sdk/path.zsh.inc ]; then
  source '/Users/miguel/Downloads/google-cloud-sdk/path.zsh.inc'
fi

# The next line enables shell command completion for gcloud.
if [ -f /Users/miguel/Downloads/google-cloud-sdk/completion.zsh.inc ]; then
  source '/Users/miguel/Downloads/google-cloud-sdk/completion.zsh.inc'
fi
