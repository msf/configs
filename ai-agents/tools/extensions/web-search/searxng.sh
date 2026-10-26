#!/bin/sh
# Local SearXNG for Pi's web_search tool, bound to 127.0.0.1 only.
# Usage: searxng.sh start|stop|status   (port: SEARXNG_PORT, default 28100)
set -eu

NAME=pi-searxng
PORT=${SEARXNG_PORT:-28100}
# Pinned for reproducibility. Engine scrapers age: bump the digest deliberately (tools/README.md).
IMAGE=searxng/searxng@sha256:76b0bf285aca014c7191fc4d9234c4bfb358624ac33d8883833d496c059ec072
SETTINGS=$(dirname "$(readlink -f "$0")")/settings.yml
HEALTH_URL=http://127.0.0.1:$PORT/healthz
HEALTH_WAIT_S=30

healthy() {
	curl -fsS --max-time 2 "$HEALTH_URL" >/dev/null 2>&1
}

start() {
	if [ ! -f "$SETTINGS" ]; then
		echo "searxng: settings must be a regular file: $SETTINGS" >&2
		return 1
	fi
	want="$IMAGE 127.0.0.1:$PORT bind:$SETTINGS:false"
	have=$(docker inspect --format \
		'{{.Config.Image}} {{(index (index .HostConfig.PortBindings "8080/tcp") 0).HostIp}}:{{(index (index .HostConfig.PortBindings "8080/tcp") 0).HostPort}}{{range .Mounts}}{{if eq .Destination "/etc/searxng/settings.yml"}} {{.Type}}:{{.Source}}:{{.RW}}{{end}}{{end}}' \
		"$NAME" 2>/dev/null || true)
	if [ -n "$have" ] && [ "$have" != "$want" ]; then
		docker rm -f "$NAME" >/dev/null
		have=
	fi
	if [ -z "$have" ]; then
		# The secret only signs SearXNG's own cookies, so a fresh one per container is enough.
		if ! docker run -d --name "$NAME" --restart unless-stopped \
			-p "127.0.0.1:$PORT:8080" \
			-e SEARXNG_SECRET="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')" \
			--mount "type=bind,src=$SETTINGS,dst=/etc/searxng/settings.yml,readonly" \
			"$IMAGE" >/dev/null; then
			# A concurrent caller may have created it; anything else is fatal.
			docker inspect "$NAME" >/dev/null 2>&1 || exit 1
		fi
	fi
	docker start "$NAME" >/dev/null
	i=0
	while [ "$i" -lt "$HEALTH_WAIT_S" ]; do
		healthy && return 0
		i=$((i + 1))
		sleep 1
	done
	echo "searxng: not healthy after ${HEALTH_WAIT_S}s; see: docker logs $NAME" >&2
	return 1
}

case ${1:-} in
start) start ;;
stop) docker rm -f "$NAME" >/dev/null ;;
status)
	if healthy; then
		echo "running: http://127.0.0.1:$PORT"
	else
		echo "not running"
		exit 1
	fi
	;;
*)
	echo "usage: $0 start|stop|status" >&2
	exit 2
	;;
esac
