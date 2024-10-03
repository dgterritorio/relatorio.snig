#!/bin/bash
#
#

if [ "$1" == "identify" ]; then
    echo "{capabilities2} {Curl based determination of capabilities}"
    exit 0
fi

. utils/shell_functions.sh

url=${args["url"]}

OUT=$(/usr/bin/curl $url)

ecode="$?"

if [ $ecode ne 0 ]; then
    echo $(make_error_result "curl_error" "error $ecode")
    exit 0
fi

echo $(make_ok_result "${#OUT} character read, tmpfile $2")
exit 0
