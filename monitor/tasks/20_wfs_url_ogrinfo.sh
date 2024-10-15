#!/bin/bash
#
# arguments are:
#
#  $1: task descriptor (processed by shell_functions.sh)
#  $2: thread private disk space
#  $3: uuid private disk space

. utils/shell_functions.sh
identify $1 "wfs_ogr_info" "WFS OGRinfo Capabilities" $2 $3 "WFS"

if [ $type != "WFS" ]; then
    echo $(make_not_applicable_result)
    exit 0
fi

if [ ! -d $uuid_space ]; then
    mkdir -p $uuid_space
fi

ogrinfo_fn="${uuid_space}/ogrinfo-${version}.txt"

ogrinfo -so wfs:"${url}" --config GDAL_HTTP_TIMEOUT $GDAL_HTTP_TIMEOUT 1> $ogrinfo_fn 2>&1
ogrinfo_rcode="$?"

if [ $ogrinfo_rcode -ne 0 ]; then
    echo $(make_error_result "timeout_error" "WFS ogrinfo failed on a $GDAL_HTTP_TIMEOUT secs timeout" "")
    exit 0
fi
#cat $ogrinfo_fn
#re_match=$(cat $ogrinfo_fn | grep -oiP "^INFO: Open of\s+.wfs:.*\s+using driver .WFS. successful.")

re_match=$(cat $ogrinfo_fn | grep "using driver \`WFS' successful")
#echo ">$re_match<"

if [ "$re_match" != "" ]; then
    ser_match=$(cat $ogrinfo_fn | grep -oiP "ServiceExceptionReport|error")
    if [ "$ser_match" != "" ]; then
        echo $(make_warning_result "valid WFS OGR info response (version $version) with warning or not fatal error")
    else
        echo $(make_ok_result "valid WFS OGR info response (version $version)")
    fi
    ogrinfo_json="${uuid_space}/ogrinfo-${version}.json"
    ogrinfo -nocount -noextent -json wfs:${url} > $ogrinfo_json 2>&1
else
    echo $(make_error_result "invalid_ogrinfo" "Invalid OGR info response")
fi

#re_match=$(cat $ogrinfo_fn | grep -oiP "INFO: Open of\s+.wfs:.*\s+using driver .WFS. successful.")
#echo ">$re_match<"
#if [ "$re_match" != "" ]; then
#    test_passed="y"
#    echo $(make_warning_result "valid WFS OGR info response (version $version) with warning or not fatal error")
#fi

exit 0
