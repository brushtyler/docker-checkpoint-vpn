#!/bin/bash

if [ -z "$SNX_SERVER" ] || [ -z "$SNX_USER" ] || [ -z "$SNX_PASS" ] || [ -z "$SNX_ROOTCA" ] ; then
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

trap 'echo; snx -d' exit

/usr/bin/expect <<EOF
spawn -ignore HUP snx -s "$SNX_SERVER" -u "$SNX_USER" $SNX_OPTIONS
# send password
expect "*?assword:"
send -- "${SNX_PASS/$/\\\$}\r"
set timeout 10
# Root CA check
expect -re {Root CA fingerprint: ([A-Z ]+)}
if {![string match "$SNX_ROOTCA" \$expect_out(1,string)]} {
  # root CA match failed
  exit 10
}
expect "Do you accept*"
send "y\r"
# wait for connected
expect "SNX - connected."
# background snx process
expect_background
exit 0
EOF

RET=$?
SNX_PID=$(pidof snx)

if [ -e "$SNX_LOGFILE" ] ; then
	# debug mode enabled, tail logfile
	echo && tail -n+1 -f "$SNX_LOGFILE" &
fi

echo

if [ $RET -eq 10 ] ; then
	# Root CA fingerprint doesn't match
	echo "Root CA fingerprint doesn't match!" >&2
	exit 1
elif [ $RET -ne 0 ] ; then
	# connection error, expect script failed
	echo "Connection error" >&2
	exit 2
elif [ -z "$SNX_PID" ] ; then
	# process failed
	echo "SNX process failed" >&2
	exit 3
fi

echo "The VPN connection is stable"

# process running, wait until finished
tail -f --pid=$SNX_PID /dev/null
