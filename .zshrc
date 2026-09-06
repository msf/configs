# History
HISTFILE=$HOME/.histfile
HISTSIZE=910000
SAVEHIST=910000
setopt appendhistory autocd extendedglob histignorealldups sharehistory no_beep
bindkey -e

# Completion
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

umask 002
export EDITOR=nvim
export LESS=-X

# Aliases
alias vim='nvim'
alias vimdiff='nvim -d'
if [[ $OSTYPE == darwin* ]]; then
  alias ls='ls -GFv'
  alias l='ls -G'
  alias la='ls -aG'
  alias ll='ls -aihlrtG'
else
  alias ls='ls -Fv --color=auto'
  alias l='ls --color=auto'
  alias la='ls -a --color=auto'
  alias ll='ls -aihlrt --color=auto'
fi
alias rm='\rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'
alias grep='grep --color=auto'
alias lock='gnome-screensaver-command -l'
alias j='jobs'
alias ipy='ipython3'
alias dstat='dstat -c -r -d -n -m -s -y --nocolor'
alias vvac='python3 -m venv env && source env/bin/activate && pip install --upgrade pip'
alias vac='source env/bin/activate'
alias gti=git
alias tmux='tmux -2'
alias k=kubectl
alias rp=rocketpool
alias snip='grim -g "$(slurp)" - | wl-copy'
alias pip=pip3
alias python=python3
alias py=python3
alias lsof='lsof -n -M'
alias day='gsettings set org.gnome.desktop.interface color-scheme prefer-light'
alias night='gsettings set org.gnome.desktop.interface color-scheme prefer-dark'


# for sway
export XKB_DEFAULT_OPTIONS=caps:ctrl
# firefox on wayland
export MOZ_ENABLE_WAYLAND=1

# Environment
export GOPRIVATE=github.com/duneanalytics
export KUBECONFIG=$HOME/.kube/config
export PYENV_ROOT=$HOME/.pyenv
export SDKMAN_DIR=$HOME/.sdkman
export WASMER_DIR=$HOME/.wasmer
export WASMER_CACHE_DIR=$WASMER_DIR/cache
export WASMTIME_HOME=$HOME/.wasmtime
export BUN_INSTALL=$HOME/.bun

typeset -U path PATH
path=(
  $HOME/bin
  $HOME/.local/bin
  $HOME/.local/share/pi-node/current/bin
  $HOME/go/bin
  $HOME/.cargo/bin
  $HOME/.fzf/bin
  $PYENV_ROOT/bin
  $PYENV_ROOT/shims
  $HOME/.tiup/bin
  $HOME/.wasmer/bin
  $WASMTIME_HOME/bin
  $HOME/.opencode/bin
  $BUN_INSTALL/bin
  $HOME/.yarn/bin
  /snap/bin
  /opt/homebrew/opt/llvm@19/bin
  /opt/homebrew/opt/coreutils/libexec/gnubin
  /opt/homebrew/bin
  /usr/local/go/bin
  /usr/local/bin
  /usr/local/sbin
  /sbin
  /usr/sbin
  $path
  /opt/nvim-linux-x86_64/bin
)

if (( $+commands[keychain] )); then
  keychain -q $HOME/.ssh/id_ed25519
  keychain_file=$HOME/.keychain/${HOST}-sh
  [[ -r $keychain_file ]] && source $keychain_file
  unset keychain_file
fi

if (( $+commands[kubectl] )); then
  _kubectl() {
    unfunction _kubectl
    source <(kubectl completion zsh)
    _kubectl "$@"
  }
  compdef _kubectl kubectl k
fi

(( $+commands[pyenv] )) && eval "$(pyenv init -)"

if [[ -s $SDKMAN_DIR/bin/sdkman-init.sh ]]; then
  path=($SDKMAN_DIR/candidates/*/current/bin(N) $path)
  sdk() {
    unfunction sdk
    source $SDKMAN_DIR/bin/sdkman-init.sh
    sdk "$@"
  }
fi

[[ -f $HOME/.zshrc_private ]] && source $HOME/.zshrc_private

function dpsql {
	PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id ${1}_${2}_db_${2}_user_password --output text --query SecretString) pgcli -U ${2} -h ${1}-${2}-db ${2}
}

# dbsh <env> <service> [dbname]
# Connects read-only: prefers -db-rr host, falls back to primary;
# prefers readonly credentials from Secrets Manager, falls back to service user.
function dbsh {
  local env="${1}" svc="${2}" db="${3:-}"

  if [[ -z "$env" || -z "$svc" ]]; then
    echo "usage: dbsh <env> <service> [dbname]" >&2
    return 1
  fi

  # Prefer read replica in Tailscale, fall back to primary
  local rr_host="${env}-${svc}-db-rr"
  local host
  if tailscale status 2>/dev/null | grep "  ${rr_host}  " | grep -qv "offline"; then
    host="$rr_host"
  else
    host="${env}-${svc}-db"
  fi

  local secret user password

  if [[ "$svc" == "core" ]]; then
    # core uses rotated blue/green credentials; the `_active` secret is a JSON
    # blob whose `username` flips between core_v2_ref_blue / _green at each
    # rotation. We bypass the in-cluster pgbouncer (host/port in the secret)
    # and connect directly to the Tailscale RDS replica with the readonly db.
    # See core/docs/db_password_rotation.md.
    secret="${env}/core/db/users/core_v2_ref_active"
    local json
    json=$(aws secretsmanager get-secret-value --secret-id "$secret" --query SecretString --output text 2>/dev/null)
    if [[ -z "$json" ]]; then
      echo "error: could not retrieve secret '$secret'" >&2
      return 1
    fi
    user=$(printf '%s' "$json" | jq -r .username)
    password=$(printf '%s' "$json" | jq -r .password)
    # dbname_readonly only routes correctly through the in-cluster pgbouncer;
    # on the RDS replica the real db is `dbname` and the replica enforces RO.
    [[ -z "$db" ]] && db=$(printf '%s' "$json" | jq -r .dbname)
  else
    [[ -z "$db" ]] && db="$svc"
    # Prefer readonly secret, fall back to service-user secret
    local secret_ro="${env}_${svc}_db_readonly_user_secret"
    if aws secretsmanager describe-secret --secret-id "$secret_ro" &>/dev/null; then
      secret="$secret_ro"
      user="readonly"
    else
      secret="${env}_${svc}_db_${svc}_user_password"
      user="$svc"
    fi
    password=$(aws secretsmanager get-secret-value --secret-id "$secret" --query SecretString --output text 2>/dev/null)
    if [[ -z "$password" ]]; then
      echo "error: could not retrieve secret '$secret'" >&2
      return 1
    fi
  fi

  echo "→ host=${host}  user=${user}  db=${db}  secret=${secret}" >&2
  PGPASSWORD="$password" psql -U "$user" -h "$host" "$db"
}

# db-root-sh <env> <service> [dbname]
# DANGER: connects to the PRIMARY with the RDS master user (full write/DDL).
# Use only when dbsh's read replica is not enough — e.g. fixing a bad row.
# Secret layout: ${env}/${svc}/db/master/${dbname:-$svc}
function db-root-sh {
  local env="${1}" svc="${2}" db="${3:-$2}"

  if [[ -z "$env" || -z "$svc" ]]; then
    echo "usage: db-root-sh <env> <service> [dbname]" >&2
    return 1
  fi

  local host="${env}-${svc}-db"
  local secret="${env}/${svc}/db/master/${db}"

  local json
  json=$(aws secretsmanager get-secret-value --secret-id "$secret" --query SecretString --output text 2>/dev/null)
  if [[ -z "$json" ]]; then
    echo "error: could not retrieve secret '$secret'" >&2
    return 1
  fi
  local user password
  user=$(printf '%s' "$json" | jq -r .username)
  password=$(printf '%s' "$json" | jq -r .password)

  print -P "%F{red}%B!! ROOT WRITE SESSION !!%b%f" >&2
  echo "   host=${host}  user=${user}  db=${db}  secret=${secret}" >&2
  local confirm
  read "confirm?   type '${env}/${svc}' to continue: "
  if [[ "$confirm" != "${env}/${svc}" ]]; then
    echo "aborted (got: '${confirm}')." >&2
    return 1
  fi

  PGPASSWORD="$password" pgcli -U "$user" -h "$host" "$db"
}

[[ -t 0 && -t 1 ]] && (( $+commands[fzf] )) && source <(fzf --zsh)
[[ -f $HOME/.zsh_prompt ]] && source $HOME/.zsh_prompt

export NVM_DIR=$HOME/.nvm
if [[ -s $NVM_DIR/nvm.sh ]]; then
  source $NVM_DIR/nvm.sh --no-use
  node_version=$(nvm version default)
  if [[ $node_version != N/A ]]; then
    export NVM_BIN=$NVM_DIR/versions/node/$node_version/bin
    path=($NVM_BIN $path)
  fi
  unset node_version
fi

alias openclaw='incus exec openclaw -- machinectl shell openclaw@'

if (( $+commands[pi] )); then
  pi() {
    [[ ! -x $HOME/bin/launch-meridian.sh ]] || $HOME/bin/launch-meridian.sh
    if [[ -x $HOME/.local/share/pi-node/current/bin/node ]]; then
      PATH="$HOME/.local/share/pi-node/current/bin:$PATH" command pi "$@"
    else
      command pi "$@"
    fi
  }
fi
