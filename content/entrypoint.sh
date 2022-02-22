#!/bin/bash

if [ -z "$SNX_SERVER" ] || [ -z "$SNX_USER" ] || [ -z "$SNX_PASS" ] || [ -z "$SNX_ROOTCA" ] ; then
	echo "Provide server, credentials and root CA params via env file or via '-e SNX_SERVER=<GATEWAY> -e SNX_USER=<USERNAME> -e SNX_PASS=<PASSWORD> -e SNX_ROOTCA=<FINGERPRINT>'." >&2
	exit 1
fi

# snx doesn't provide option to configure logfile path
SNX_LOGFILE=/root/snx.elg
rm -f "$SNX_LOGFILE"

# debug mode, i.e. create log file
if [ -n "$SNX_DEBUG" ] ; then
	SNX_OPTIONS="$SNX_OPTIONS -g"
fi

trap 'echo && echo "SNX process finished with exitcode $?" && snx -d' exit

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
SNX_PID=$(pidof snx)

if [ -e "$SNX_LOGFILE" ] ; then
	# debug mode enabled, tail logfile
	echo && tail -f "$SNX_LOGFILE" &
fi

if [ $RET -ne 0 ] ; then
	# connection error, expect script failed
	exit 1
fi

# wait few seconds and check for snx process still running
sleep 5
if ! pidof snx &> /dev/null ; then
	# connection error, snx process failed after a while
	exit 2
fi

# process running, wait until finished
tail -f --pid=$SNX_PID /dev/null
