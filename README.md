# docker-checkpoint-vpn

Usage:

```sh
# Clone the repo
git clone https://github.com/brushtyler/docker-checkpoint-vpn.git
cd docker-checkpoint-vpn

# Build the container
./build.sh

# Create the configuration file
cp config.env.sample config.env
edit config.env

# Run the VPN client:

#   1. use host networking
#   No need to specify routes, all the routes pushed by the VPN server will be added to the host
./start.sh -c config.env --use-host-net

# OR

#   2. use container networking
#   You need to specify which routes must be use the container as gateway
./start.sh -c config.env -r 192.168.100.0/24 -r 172.20.0.0/16
```
