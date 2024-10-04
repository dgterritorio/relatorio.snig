#!/bin/bash
#
# arguments are:
#
#  $1: task descriptor (processed by shell_functions.sh)
#  $2: thread private disk space
#  $3: uuid private disk space

. utils/shell_functions.sh
identify $1 "wfs_ogr_info" "WFS OGRinfo Capabilities" $2 $3

if [ $type != "WFS" ]; then
    echo $(make_not_applicable_result)
    exit 0
fi

OGRINFO=$(ogrinfo -so wfs:${url})

if [ ! -d $uuid_space ]; then
    mkdir -p $uuid_space
fi

ogrinfo_fn="${uuid_space}/ogrinfo-${version}.txt"
echo $OGRINFO > $ogrinfo_fn

re_match=$(echo $OGRINFO | grep -oP "^INFO: Open of\s+.wfs:.*\s+using driver .WFS. successful.")
if [ "$re_match" != "" ]; then
    echo $(make_ok_result "valid WFS OGR info response (version $version)")
    exit 0
fi

re_match=$(echo $OGRINFO | grep -oP "INFO: Open of \`wfs:.*'.* using driver \`WFS' successful.")
if [ "$re_match" != "" ]; then
    echo $(make_warning_result "valid WFS OGR info response (version $version) with warning or not fatal error")
    exit 0
fi

echo $(make_error_result "invalid_ogrinfo" "Invalid OGR info response")
exit 0
