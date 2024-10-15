#!/bin/bash
#
# arguments are:
#
#  $1: record gid (primary key)
#  $2: url
#  $3: thread private disk space
#  $4: uuid private disk space

. utils/shell_functions.sh
identify $1 "url_status_codes" "Check URL Status Codes" $2 $3 "all"

status_code_and_time=$( TIMEFORMAT="%R"; { time curl -X GET --max-time $TIMEOUT -o /dev/null -Isw '%{http_code}\n' "$url"; } 2>&1 )
status_code_and_time_single_line=$(echo "$status_code_and_time" | tr '\n' ' ')
sc=$(echo $status_code_and_time_single_line | cut -d " " -f1)
time=$(echo $status_code_and_time_single_line | cut -d " " -f2)
time_dot=$(echo $time | sed 's/,/./')

#echo $sc
#echo $time_dot
#record="$field1""$""$field7""$""$field52""$""${!url}""$""$sc""$""$time_dot"
#echo "$record" >> snig_geonetwork_records_urls_status_codes.csv

valid_code=$(echo $sc | grep -oP ${HTTP_VALID_CODES})
if [ "$valid_code" == "" ]; then
    echo $(make_error_result "invalid_http_code" "Invalid HTTP status code $sc")
else
    echo $(make_ok_result "http_status_code: $sc ping_time: $time_dot")
fi
exit 0
