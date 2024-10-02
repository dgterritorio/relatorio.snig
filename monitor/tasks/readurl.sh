#!/bin/bash
#
#

if [ "$1" == "identify" ]; then
    echo "{capabilities2} {Curl based determination of capabilities}"
    exit 0
fi

. utils/shell_functions.sh

OUT=$(/usr/bin/curl $1)

echo "ok {} {} {${#OUT} character read, tmpfile $2}"

exit 0
