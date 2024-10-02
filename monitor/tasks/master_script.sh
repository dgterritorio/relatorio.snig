#!/bin/bash
#
#
if [ "$1" == "identify" ]; then
    echo "{testbed} {Task to be used for development and not included}"
    exit 0
fi
. utils/shell_functions.sh

if [ "$2" != "" ]; then
    invalid_command 
    ecode="$?"
    if [ $ecode -ne 0 ]; then 
        echo $(make_error_result "invalid_command" "invalid command (error: $ecode)")
        exit 0
    fi
fi
echo $(make_ok_result "Success")

exit 0
