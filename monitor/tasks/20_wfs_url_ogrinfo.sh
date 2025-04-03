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

if [ ! -d $uuid_space ]; then
    mkdir -p $uuid_space
fi

ogrinfo_fn="${uuid_space}/ogrinfo-${version}.txt"
ogrinfo -so wfs:"${url}" 1> $ogrinfo_fn 2>&1

maybe_successful=0
error_detected=0
while IFS= read -r line; do
    if [[ "$line" =~ using\ driver\ .WFS.\ successful ]]; then
        maybe_successful=1
    elif [[ "$line" =~ ERROR\ ([0-9]+):\ (.*)\ \(([0-9]+)\) ]]; then
        ERROR_LEVEL="${BASH_REMATCH[1]}"
        ERROR_MESSAGE="${BASH_REMATCH[2]}"
        ERROR_CODE="${BASH_REMATCH[3]}"
        error_detected=1
    elif [[ "$line" =~ ERROR\ ([0-9]+):\ (.*) ]]; then
        ERROR_LEVEL="${BASH_REMATCH[1]}"
        ERROR_MESSAGE="${BASH_REMATCH[2]}"
        error_detected=2
    fi
done < "$ogrinfo_fn"


if [[ $maybe_successful -eq 1 ]]; then 
    case $error_detected in
        0)
            echo $(make_ok_result "valid WFS OGR info response (version $version)") ;;
        1)
            echo $(make_warning_result "Service exception or error" \
                                       "Non fatal error ($ERROR_MESSAGE) with code $ERROR_CODE" \
                                       "Valid WFS OGR info with warning or not fatal error") ;;
        2)
            echo $(make_warning_result "Service exception or error" \
                                       "Service exception or error ($ERROR_MESSAGE)" \
                                       "Valid WFS OGR info with warning or not fatal error") ;;
    esac
else
    case $error_detected in
        0)
            echo $(make_error_result "Invalid ogrinfo response" "Invalid OGR info response") ;;
        1)
            echo $(make_error_result "WFS OGR error" \
                                     "Fatal error ($ERROR_MESSAGE) with code $ERROR_CODE" \
                                     "Invalid WFS OGR info: $ERROR_MESSAGE (code $ERROR_CODE)") ;;
        2)
            echo $(make_warning_result "WFS OGR error" \
                                       "Service exception or error ($ERROR_MESSAGE)" \
                                       "Invalid WFS OGR info: $ERROR_MESSAGE (code $ERROR_CODE)") ;;
    esac
fi

exit 0
