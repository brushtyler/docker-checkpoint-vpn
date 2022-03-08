#!/bin/bash

CONFIGENVFILE="${1:-config.env}"
IMAGENAME=snx-checkpoint-vpn
CONTAINERNAME="${2:-snx-vpn}"
USEHOSTNET="${3:-n}"

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

OPTARGS=()
if [[ "$USEHOSTNET" == 'y' ]] ; then
	OPTARGS+=('--net=host')
fi

CONTAINERID="$(docker run --name "$CONTAINERNAME" \
	--cap-add=NET_ADMIN \
	"${OPTARGS[@]}" \
	-v /lib/modules:/lib/modules \
	--env-file "$CONFIGENVFILE" \
	--rm -t -d "$IMAGENAME")"

if [[ "$USEHOSTNET" != 'y' ]] ; then
	docker exec -it "$CONTAINERNAME" iptables -t nat -A POSTROUTING -o tunsnx -j MASQUERADE
	docker exec -it "$CONTAINERNAME" iptables -A FORWARD -i eth0 -j ACCEPT
	GATEWAY="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$CONTAINERNAME")"
	echo -n "$CONTAINERNAME IP address: ${GATEWAY}"
	echo "$CONTAINERNAME Routing table: " && docker exec -it "$CONTAINERNAME" route -n | grep -v eth0
	echo
	echo "Add local routes for networks reachable via VPN by running:"
	echo "  sudo route add -net <NETWORK> netmask <NETMASK> gw ${GATEWAY}"
fi

docker attach "$CONTAINERID"
