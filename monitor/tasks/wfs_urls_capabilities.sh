#!/bin/bash
#
# arguments are:
#
#  $1: task descriptor (processed by shell_functions.sh)
#  $2: thread private disk space
#  $3: uuid private disk space

. utils/shell_functions.sh
identify $1 "wfs_capabilities" "WFS Capabilities" 

tmp_space=$2
uuid_space=$3

url=${args["url"]}
type=${args["type"]}
version=${args["version"]}

if [ $type != "WFS" ]; then
    echo $(make_ok_error "not applicable")
    exit 0
fi

XML=$(curl -X GET "$url")
curl_rcode="$?"

if [ $curl_rcode -ne 0 ]; then
    XML=$(wget "$url")
    wget_rcode="$?"
    if [ $wget_rcode ne 0]; then
        echo $(make_error_result "download_failure" \
                                 "Capabilities version ${version} download failed (curl error: $curl_rcode, wget error: $wget_rcode)" "")
        exit 0
    fi
fi

if [ ! -d $uuid_space ]; then
    mkdir -p $uuid_space
fi

capabilities_fn="${uuid_space}/capabilities-${version}.xml"

echo $XML > $capabilities_fn

xmlvalid=$(xmlstarlet validate $capabilities_fn | grep invalid)

if [ -z "$xmlvalid" ]; then 
    echo $(make_ok_result "valid WFS Capabilities XML document version $version")
else 
    echo $(make_error_result "invalidxml" "Invalid XML Capabilities Document $version")
fi
