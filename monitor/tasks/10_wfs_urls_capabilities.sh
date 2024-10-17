#!/bin/bash
#
# arguments are:
#
#  $1: task descriptor (processed by shell_functions.sh)
#  $2: thread private disk space
#  $3: uuid private disk space

. utils/shell_functions.sh
identify $1 "wfs_capabilities" "WFS Capabilities" $2 $3 "WFS"

if [ $type != "WFS" ]; then
    echo $(make_not_applicable_result)
    exit 0
fi

if [ ! -d $uuid_space ]; then
    mkdir -p $uuid_space
fi
capabilities_fn="${uuid_space}/wfs-capabilities-${version}.xml"

curl --max-time $TIMEOUT --output $capabilities_fn -X GET "$url"
curl_rcode="$?"

if [ $curl_rcode -ne 0 ]; then
    wget --timeout=$TIMEOUT --output-document=$capabilities_fn --tries=1 "$url"
    wget_rcode="$?"
    if [ $wget_rcode ne 0]; then

        if [[ $curl_rcode -eq 28 && $wget_rcode -eq 4 ]]; then
            echo $(make_error_result "timeout error" \
                 "Capabilities version ${version} failed on a $TIMEOUT secs error" "")   
        else
            echo $(make_error_result "download_failure" \
                "Capabilities version ${version} download failed (curl error: $curl_rcode, wget error: $wget_rcode)" "")
        fi

        exit 0
    fi
fi

xmlvalid=$(xmlstarlet validate $capabilities_fn | grep invalid)

if [ -z "$xmlvalid" ]; then 
    echo $(make_ok_result "valid WFS Capabilities XML document version $version")
else 
    echo $(make_error_result "invalidxml" "Invalid XML Capabilities Document $version")
fi
exit 0
