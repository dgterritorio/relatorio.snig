#!/bin/bash
#
#
if [ "$1" == "identify" ]; then
    echo "{testbed} {Task to be used for development and not included}"
    exit 0
fi

if [ "$2" != "" ]; then
    invalid_command 
    ecode="$?"
    test $ecode -ne 0 && echo error {invalid_command} {invalid command (error: $ecode)} {} && exit 0
fi
echo OK {} {} {}

exit 0
