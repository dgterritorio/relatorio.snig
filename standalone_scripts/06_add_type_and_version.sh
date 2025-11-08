#!/bin/bash

# This script will take the CSV, in \"wide\" format, that contains the harvested services URLs
# and will generate a \"long\" version of the same table were the URLs have been \"sanitized\" and where the protocol version and type
# are also added, because frequentely the service URLs in metadata are not well written and version and protocol type are
# often not desribed at all

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# ------------------------------------------------------------------
# STEP 1 — Expand wide CSV (multiple URLs per record) into long form
# ------------------------------------------------------------------
input_file="$BASEFOLDER/geonetwork_records_urls_wide.csv"
output_file="$BASEFOLDER/step1.csv"

> "$output_file"

while IFS= read -r line; do
    IFS='$' read -r -a cols <<< "$line"

    col1="${cols[0]}"
    col2="${cols[1]}"
    col3="${cols[2]}"

    # Loop from 3 to end (bash arrays are zero-indexed)
    for ((i=3; i<${#cols[@]}; i++)); do
        url="${cols[$i]}"
        [ -z "$url" ] && continue

        additional_field="OTHER"
        if echo "$url" | grep -iq "wms"; then
            additional_field="WMS"
        elif echo "$url" | grep -iq "wfs"; then
            additional_field="WFS"
        elif echo "$url" | grep -iq "wcs"; then
            additional_field="WCS"
        elif echo "$url" | grep -iq "ows"; then
            additional_field="OWS"
        fi

        echo "$col1\$${col2}\$${col3}\$${url}\$${additional_field}" >> "$output_file"
    done
done < "$input_file"


echo "[STEP 1] Created $output_file"

# ------------------------------------------------------------------
# STEP 2 — Assign version per service type
# ------------------------------------------------------------------
input_file="$BASEFOLDER/step1.csv"
output_file="$BASEFOLDER/step2.csv"
> "$output_file"

while IFS='$' read -r col1 col2 col3 col4 col5; do
    new_field=""

    case "$col5" in
        WMS) new_field="1.3.0" ;;
        WFS)
            if echo "$col4" | grep -q "2.0.0"; then
                new_field="2.0.0"
            elif echo "$col4" | grep -q "1.1.0"; then
                new_field="1.1.0"
            elif echo "$col4" | grep -q "1.0.0"; then
                new_field="1.0.0"
            else
                new_field="2.0.0"
            fi
            ;;
        WCS)
            if echo "$col4" | grep -q "2.0.1"; then
                new_field="2.0.1"
            elif echo "$col4" | grep -q "2.0.0"; then
                new_field="2.0.0"
            elif echo "$col4" | grep -q "1.1.1"; then
                new_field="1.1.1"
            elif echo "$col4" | grep -q "1.0.0"; then
                new_field="1.0.0"
            else
                new_field="1.1.1"
            fi
            ;;
        OWS) new_field="" ;;
        OTHER) new_field="" ;;
    esac

    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${new_field}" >> "$output_file"
done < "$input_file"

echo "[STEP 2] Created $output_file"

# ------------------------------------------------------------------
# STEP 3 — Duplicate records per version rules
# ------------------------------------------------------------------
input_file="$BASEFOLDER/step2.csv"
output_file="$BASEFOLDER/step3.csv"
temp_file=$(mktemp)
> "$temp_file"

while IFS='$' read -r col1 col2 col3 col4 col5 col6; do
    case "$col5" in
        OTHER|WMS)
            echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}" >> "$temp_file"
            ;;
        WFS)
            case "$col6" in
                1.0.0)
                    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}" >> "$temp_file"
                    ;;
                1.1.0)
                    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.1.0" >> "$temp_file"
                    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.0.0" >> "$temp_file"
                    ;;
                2.0.0)
                    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$2.0.0" >> "$temp_file"
                    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.1.0" >> "$temp_file"
                    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.0.0" >> "$temp_file"
                    ;;
            esac
            ;;
        WCS)
            case "$col6" in
                2.0.0)
                    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$2.0.0" >> "$temp_file"
                    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.1.1" >> "$temp_file"
                    ;;
                1.1.1)
                    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.1.1" >> "$temp_file"
                    ;;
            esac
            ;;
        OWS)
            echo "$col1\$${col2}\$${col3}\$${col4}\$WMS\$1.3.0" >> "$temp_file"
            echo "$col1\$${col2}\$${col3}\$${col4}\$WFS\$2.0.0" >> "$temp_file"
            echo "$col1\$${col2}\$${col3}\$${col4}\$WFS\$1.1.0" >> "$temp_file"
            echo "$col1\$${col2}\$${col3}\$${col4}\$WFS\$1.0.0" >> "$temp_file"
            ;;
    esac
done < "$input_file"

sort -t'$' -k4,4 "$temp_file" > "$output_file"
rm "$temp_file"

echo "[STEP 3] Created $output_file"

# ------------------------------------------------------------------
# STEP 4 — Construct proper GetCapabilities URLs
# ------------------------------------------------------------------
input_file="$BASEFOLDER/step3.csv"
output_file="$BASEFOLDER/geonetwork_records_urls_long_with_type.csv"
> "$output_file"

while IFS='$' read -r col1 col2 col3 col4 col5 col6; do
    if [ "$col5" == "OTHER" ]; then
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}\$" >> "$output_file"
        continue
    fi

    # Clean URL base (remove ? and trailing ?)
    url_without_query="${col4%%\?*}"
    [[ "${col4}" == *"?" ]] && url_without_query="${col4%?}"

    # Construct final GetCapabilities URL
    if [[ "$col4" == *"map="* ]]; then
        map_param="${col4#*map=}"
        new_url="${url_without_query}?service=${col5}&version=${col6}&request=GetCapabilities&map=${map_param}"
    else
        new_url="${url_without_query}?service=${col5}&version=${col6}&request=GetCapabilities"
    fi

    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}\$${new_url}" >> "$output_file"
done < "$input_file"

rm "$BASEFOLDER"/step*.csv
echo "[DONE] Processing complete. Output written to $output_file"
