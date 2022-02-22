#!/bin/bash

if [ -z "$SNX_SERVER" ] || [ -z "$SNX_USER" ] || [ -z "$SNX_PASS" ] || [ -z "$SNX_ROOTCA" ] ; then
	echo "Provide server, credentials and root CA params via env file or via '-e SNX_SERVER=<GATEWAY> -e SNX_USER=<USERNAME> -e SNX_PASS=<PASSWORD> -e SNX_ROOTCA=<FINGERPRINT>'." >&2
	exit 1
fi

# snx doesn't provide option to configure logfile path
SNX_LOGFILE=/root/snx.elg
rm -f "$SNX_LOGFILE"

trap 'echo && snx -d' exit

/usr/bin/expect <<EOF
spawn snx -s "$SNX_SERVER" -u "$SNX_USER" $SNX_OPTIONS
expect "*?assword:"
send "${SNX_PASS/$/\\\$}\r"
expect "Root CA fingerprint: $SNX_ROOTCA"
expect "Do you accept*"
send "y\r"
expect "SNX - connected."
interact
EOF

RET=$?

# print logs if any
[ -e "$SNX_LOGFILE" ] && tail "$SNX_LOGFILE"

if [ $RET -ne 0 ] ; then
	# connection error, expect failed
	exit 1
fi

# process running, wait until finished
SNX_PID=$(pidof snx)
tail -f --pid=$SNX_PID /dev/null
