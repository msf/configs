#!/bin/sh

curl -sS --max-time 1 http://127.0.0.1:3456/health >/dev/null 2>&1 && exit 0
command -v meridian >/dev/null 2>&1 || {
    echo "meridian is not installed; Anthropic models in Pi will not work" >&2
    exit 1
}

cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}
mkdir -p "$cache_dir"
nohup meridian >"$cache_dir/meridian.log" 2>&1 &
