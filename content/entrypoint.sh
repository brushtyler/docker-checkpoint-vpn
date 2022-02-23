#!/bin/bash


if [ -z "$SNX_SERVER" ] || [ -z "$SNX_USER" ] || [ -z "$SNX_PASS" ] || [ -z "$SNX_ROOTCA" ] ; then
	sleep 0.5 # give time to docker attach in order to print the error message
	echo "Provide SNX_SERVER, SNX_USER, SNX_PASS and SNX_ROOTCA using config.env env file" >&2
	exit 1
fi

# snx doesn't provide option to configure logfile path
SNX_LOGFILE=/root/snx.elg
rm -f "$SNX_LOGFILE"

# debug mode, i.e. create log file
if [ -n "$SNX_DEBUG" ] ; then
	SNX_OPTIONS="$SNX_OPTIONS -g"
fi

trap 'echo && snx -d' exit

/usr/bin/expect <<EOF
spawn snx -s "$SNX_SERVER" -u "$SNX_USER" $SNX_OPTIONS
expect "*?assword:"
send "${SNX_PASS/$/\\\$}\r"
set timeout 10
expect -re {Root CA fingerprint: ([A-Z ]+)}
if {![string match "$SNX_ROOTCA" \$expect_out(1,string)]} {
  exit 10
}
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

echo

if [ $RET -eq 10 ] ; then
	# Root CA fingerprint doesn't match
	echo "Root CA fingerprint doesn't match!" >&2
	exit 1
elif [ $RET -ne 0 ] ; then
	# connection error, expect script failed
	echo "Connection error" >&2
	exit 1
fi

# wait few seconds and check for snx process still running
echo -n "Wait for a stable connection"
COUNT=8
while pidof snx &> /dev/null ; do
	echo -n '.'
	sleep 1
	COUNT=$((COUNT-1))
	[ $COUNT -eq 0 ] && break
done
echo
if ! pidof snx &> /dev/null ; then
	# connection error, snx process failed after a while
	echo "SNX process seems stalled! Wait a minute before retrying..." >&2
	exit 2
fi

echo "The VPN connection is stable"

# process running, wait until finished
tail -f --pid=$SNX_PID /dev/null
