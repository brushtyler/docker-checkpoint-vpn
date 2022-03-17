#!/bin/bash
if [[ $EUID -ne 0 ]] ; then
	exec sudo "$0" "$@"
fi

function help() {
	echo "Usage: $(basename "$0") [-c|--config <CONFIG_ENVFILE>] [-n|--name <CONTAINER_NAME>] [--use-host-net] [-r|--add-route <NETWORK>]*

where:
-c|--config <CONFIG_ENVFILE>  VPN configuration, see config.env.sample
                              (default: config.env)

-n|--name <CONTAINER_NAME>    name to be assigned to the container
                              (default: snx-vpn)

--use-host-net                use host's network, i.e. change host's routes
                              and interfaces instead of keep them within
                              the container (default: no)

-r|--add-route <NETWORK>      add the following routes to the host using
                              container IP as gateway,
                              useful when --use-host-net is not provided" >&2
}

function parse_args() {
	while [[ ! -z "$1" ]] ; do
		case "$1" in
			-c|--config)
				CONFIGENVFILE="$2"
				shift 2
				;;
			-n|--name)
				CONTAINERNAME="$2"
				shift 2
				;;
			-r|--add-route)
				ROUTES+=("$2")
				shift 2
				;;
			--use-host-net)
				USEHOSTNET=y
				shift 1
				;;
			*)
				echo "Invalid param passed $1" >&2
				exit 1
		esac
	done
}

CONFIGENVFILE=config.env
IMAGENAME=snx-checkpoint-vpn
CONTAINERNAME=snx-vpn
USEHOSTNET=n
ROUTES=()

parse_args "$@"

[[ -z "$CONFIGENVFILE" ]] && exit 2
[[ -z "$IMAGENAME" ]] && exit 2
[[ -z "$CONTAINERNAME" ]] && exit 2


function cleanup() {
	echo
	if [[ "$USEHOSTNET" != 'y' ]] && [[ ! -z "$GATEWAY" ]] ; then
		del_routes
	fi
	echo
	#if [[ ! -z "$ATTACHPID" ]] ; then
	#	kill -9 "$ATTACHPID" &>/dev/null
	#fi
	echo "Stopping $CONTAINERNAME..."
	docker stop "$CONTAINERNAME"
}

function add_routes() {
	for NET in "${ROUTES[@]}"; do
		echo "Adding route $NET via $GATEWAY"
		sudo ip route add "$NET" via "$GATEWAY"
	done
}

function del_routes() {
	echo "Cleanup routes..."
	for NET in "${ROUTES[@]}"; do
		sudo ip route del "$NET" via "$GATEWAY"
	done
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

RUNARGS=()
RUNARGS+=(-v /lib/modules:/lib/modules) # to load tun module
RUNARGS+=(--cap-add=NET_ADMIN)
if [[ "$USEHOSTNET" == 'y' ]] ; then
	RUNARGS+=(--net=host)
fi

# start container
echo "$CONTAINERNAME starting..."
echo

CONTAINERID="$(docker run --name "$CONTAINERNAME" \
	"${RUNARGS[@]}" \
	--env-file "$CONFIGENVFILE" \
	--rm -t -d "$IMAGENAME")"

# display container output
docker container attach "$CONTAINERID" --no-stdin &
ATTACHPID=$!

# wait until connection succeeded
while true ; do
	if ! docker ps | grep "$CONTAINERNAME" &> /dev/null ; then
		# connection failed
		exit 1
	fi

	if docker logs "$CONTAINERID" | grep "VPN is connected" >/dev/null ; then
		# connection succeeded
		break
	fi
	sleep 1
done

echo

if [[ "$USEHOSTNET" != 'y' ]] ; then
	# not using host's network, container will forward our requests

	# retrieve container IP address
	GATEWAY="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$CONTAINERNAME")"
	echo "Container $CONTAINERNAME IP address: $GATEWAY"
	echo

	# enable forwarding
	docker exec -it "$CONTAINERNAME" iptables -t nat -A POSTROUTING -o tunsnx -j MASQUERADE
	docker exec -it "$CONTAINERNAME" iptables -A FORWARD -i eth0 -j ACCEPT

	# print container routing table
	echo "Container $CONTAINERNAME Routing table: "
	docker exec -it "$CONTAINERNAME" route -n | grep -v eth0
	echo

	# add provided routes
	add_routes
fi

# wait until container is stopped
wait $ATTACHPID
