#!/bin/bash

CONFIGENVFILE="${1:-config.env}"
IMAGENAME=snx-checkpoint-vpn
CONTAINERNAME="${2:-snx-vpn}"

function help() {
	echo "Usage: $(basename "$0") <CONFIG_ENVFILE> [<CONTAINER_NAME>]

where:
CONFIG_ENVFILE  VPN configuration, see config.env.sample (default: config.env)
CONTAINER_NAME  name to be assigned to the container (default: snx-vpn)" >&2
}

function cleanup() {
	echo
	echo "Stopping $CONTAINERNAME..."

	docker stop "$CONTAINERNAME"
}

if [ ! -e "$CONFIGENVFILE" ] ; then
	echo "File $CONFIGENVFILE not found..." >&2
	help && exit 1
fi

if docker ps | grep "$CONTAINERNAME" &> /dev/null ; then
	echo "Container $CONTAINERNAME is already running" >&2
	exit 2
fi

# perform cleanup on exit
trap "cleanup" EXIT

echo "$CONTAINERNAME started..."
echo

CONTAINERID="$(docker run --name "$CONTAINERNAME" \
	--cap-add=NET_ADMIN --net=host \
	-v /lib/modules:/lib/modules \
	--env-file "$CONFIGENVFILE" \
	--rm -t -d "$IMAGENAME")"
docker attach "$CONTAINERID"
