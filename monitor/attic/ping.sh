#!/bin/bash
#
#

. utils/shell_functions.sh
identify $1 "pingservice" "Checks Connectivity Using Ping"

error_handler ()
{
    echo "Error: ($?) $1"
    exit 0
}

url=${args["url"]}

ping_output=$(echo "$1" | awk -F/ '{print $3}' | xargs /bin/ping -W 1 -w 1 -c 2)
ecode="$?"

if [[ $ecode -ne 0 ]]; then
    echo $(make_error_result pingerror "ping error" "ping error code $ecode")
    exit 0
fi

echo $(make_ok_result "Success")
exit 0
