#!/bin/bash
#
# arguments are:
#
#  $1: task descriptor (processed by shell_functions.sh)
#  $2: thread private disk space
#  $3: uuid private disk space

. utils/shell_functions.sh
identify $1 "wms_gdal_info" "WMS GDAL info Capabilities" $2 $3 "WMS"

if [ $type != "WMS" ]; then
    echo $(make_not_applicable_result)
    exit 0
fi

if [ ! -d $uuid_space ]; then
    mkdir -p $uuid_space
fi

gdalinfo_fn="${uuid_space}/gdalinfo-${version}.txt"

gdalinfo wms:"${url}"--config GDAL_HTTP_TIMEOUT $GDAL_HTTP_TIMEOUT 1> $gdalinfo_fn 2>&1
gdal_rcode="$?"

if [ $gdal_rcode -ne 0 ]; then
    echo $(make_error_result "timeout_error" "WMS GDAL info response failed on a $GDAL_HTTP_TIMEOUT secs timeout" "")
fi

#cat $ogrinfo_fn
#re_match=$(cat $ogrinfo_fn | grep -oiP "^INFO: Open of\s+.wfs:.*\s+using driver .WFS. successful.")

re_match=$(cat $gdalinfo_fn | grep "Driver: WMS/OGC Web Map Service")
#echo ">$re_match<"

if [ "$re_match" != "" ]; then
    ser_match=$(cat $gdalinfo_fn | grep -oiP "ServiceExceptionReport|error")
    if [ "$ser_match" != "" ]; then
        echo $(make_warning_result "incomplete_info" "valid WMS GDAL info response (version $version) with warning or not fatal error")
    else
        echo $(make_ok_result "valid WMS GDAL info response (version $version)")
    fi
    gdalinfo_json="${uuid_space}/gdalinfo-${version}.json"
    gdalinfo -json wms:${url} > $gdalinfo_json 2>&1
else
    echo $(make_error_result "invalid_gdalinfo" "Invalid GDAL info response")
fi

exit 0
