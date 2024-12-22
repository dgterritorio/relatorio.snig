#!/bin/bash
#
# arguments are:
#
#  $1: record gid (primary key)
#  $2: url
#  $3: thread private disk space
#  $4: uuid private disk space

. utils/shell_functions.sh
identify $1 "url_status_codes" "Check URL Status Codes" $2 $3

json_txt=$(curl -X GET --head --max-time $TIMEOUT -o /dev/null -s -w '%{json}' "$url")

http_code=$(echo $json_txt | jq '.response_code')

if [ "$http_code" == "200" ]; then
    echo $(make_ok_result "http_status_code: $http_code")
elif [ $http_code == 301 ] || [ $http_code == 302 ] || [ $http_code == 303 ]; then

    redirect_url=$(echo $json_txt | /usr/bin/jq -r '.redirect_url')
    redir_http_code=$(curl -o /dev/null -s -w '%{response_code}' --location --max-redirs 5 "$redirect_url")

    if [ $redir_http_code == 200 ]; then
        echo $(make_warning_result "success_after_redirect" "$redir_http_code" "Success with http code $redir_http_code after redir ($http_code) was issued")
    else
        echo $(make_error_result "invalid_http_code" "Invalid HTTP status code $http_code after redir" "$http_code")
    fi

else
    echo $(make_error_result "invalid_http_code" "Invalid HTTP status code $http_code" "$http_code")
fi

exit 0
