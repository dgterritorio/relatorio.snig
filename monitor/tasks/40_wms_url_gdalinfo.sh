#!/bin/bash
#
# arguments are:
#
#  $1: task descriptor (processed by shell_functions.sh)
#  $2: thread private disk space
#  $3: uuid private disk space

. utils/shell_functions.sh
identify $1 "wms_gdal_info" "WMS GDAL info Capabilities" $2 $3

if [ $type != "WMS" ]; then
    echo $(make_not_applicable_result)
    exit 0
fi

if [ ! -d $uuid_space ]; then
    mkdir -p $uuid_space
fi

gdalinfo_fn="${uuid_space}/gdalinfo-${version}.txt"
#gdalinfo wms:"${url}" --config GDAL_HTTP_TIMEOUT $GDAL_HTTP_TIMEOUT 1> $gdalinfo_fn 2>&1

gdalinfo wms:"${url}" 1> $gdalinfo_fn 2>&1

maybe_successful=0
error_detected=0
while IFS= read -r line; do
    if [[ "$line" =~ Driver:\ WMS.OGC\ Web\ Map\ Service ]]; then
        maybe_successful=1
    fi

    if [[ $error_detected -eq 0 ]]; then
        if [[ "$line" =~ ERROR\ ([0-9]+):\ (.*)\ \(([0-9]+)\) ]]; then
            ERROR_LEVEL="${BASH_REMATCH[1]}"
            ERROR_MESSAGE="${BASH_REMATCH[2]}"
            ERROR_CODE="${BASH_REMATCH[3]}"
            error_detected=1
        elif [[ "$line" =~ ERROR\ ([0-9]+):\ (.*) ]]; then
            ERROR_LEVEL="${BASH_REMATCH[1]}"
            ERROR_MESSAGE="${BASH_REMATCH[2]}"
            ERROR_CODE=""
            error_detected=2
	elif [[ "$line" =~ ServiceExceptionReport || "$line" =~ error ]]; then
            ERROR_LEVEL="1"
            ERROR_MESSAGE="Service Exception Report"
            ERROR_CODE=""
            error_detected=3
        fi
    fi

    if [[ ($error_detected -gt 0) && ($maybe_successful -gt 0) ]]; then
        break
    fi
done < "$gdalinfo_fn"

if [[ $maybe_successful -eq 1 ]]; then
    case $error_detected in
        0)
            echo $(make_ok_result "Valid WMS GDAL info response (version $version)") ;;
        1)
            echo $(make_warning_result "Service exception or error" \
                                       "Non fatal error ($ERROR_MESSAGE) with code $ERROR_CODE" \
                                       "Valid WMS GDAL info with warning or not fatal error") ;;
        2)
            echo $(make_warning_result "Service exception or error" \
                                       "Service exception or error ($ERROR_MESSAGE)" \
				                        "Service exception or error ($ERROR_MESSAGE)") ;;
        3)
            echo $(make_warning_result "$ERROR_MESSAGE" \
                                       "Service exception or error ($ERROR_MESSAGE)" \
                                       "Valid WMS GDAL info with warning or not fatal error") ;;
    esac
else
    case $error_detected in
        0)
            echo $(make_error_result "Invalid WMS GDAL info response" "Invalid GDAL info response") ;;
        1)
            echo $(make_error_result "WMS GDAL error" \
                                     "Fatal error ($ERROR_MESSAGE) with code $ERROR_CODE" \
                                     "Invalid WMS GDAL info: $ERROR_MESSAGE (code $ERROR_CODE)") ;;
        2)
            echo $(make_error_result "WMS GDAL error" \
                                     "Service exception or error" \
                                     "Invalid WMS GDAL info") ;;
        3)
            echo $(make_error_result "WMS GDAL error" \
                                     "Service exception or error" \
                                     "Invalid WMS GDAL info") ;;
    esac
fi

exit 0
