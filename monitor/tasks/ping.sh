#!/bin/bash
#
#

if [ "$1" == "identify" ]; then
    echo "{pingservice} {Checks Connectivity Using Ping}"
    exit 0
fi 

error_handler ()
{
    echo "Error: ($?) $1"
    exit 0
}

echo "$1" | awk -F/ '{print $3}' | xargs /bin/ping -W 10 -w 10 -c 2
ecode="$?"

test $ecode -ne 0 && echo error {ping error} {error code $ecode} {} && exit 0
echo OK {} {} {}
exit 0
