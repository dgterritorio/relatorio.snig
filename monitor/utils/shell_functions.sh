#!/bin/bash
#
#

function make_ok_result ()
{
    echo "ok {} {} {$1} {$(date +%s)}"
}

function make_error_result ()
{
    echo "error {$1} {$2} {$3} {$(date +%s)}"
}

function make_warning_result ()
{
    echo "warning {$1} {$2} {$3} {$(date +%s)}"
}

declare -A args

function identify()
{
    if [ "$1" == "identify" ]; then
        echo "{$2} {$3}"
        exit 0
    else
        args["gid"]=$(echo "$1" | cut -f1 -d\|)
        args["url"]=$(echo "$1" | cut -f2 -d\|)
        args["uuid"]=$(echo "$1" | cut -f3 -d\|)
        args["type"]=$(echo "$1" | cut -f4 -d\|)
        args["version"]=$(echo "$1" | cut -f5 -d\|)
    fi
}


