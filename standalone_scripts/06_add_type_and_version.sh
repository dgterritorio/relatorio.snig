#!/bin/bash

# This script will take the CSV, in \"long\" format, that contains the harvested services URLs
# and will generate a copy of the same fiel were the URLs have been \"sanitized\" and where the protool version and type
# are also added, because frequentely the service URLs in metadata are not well written and version and protocal type are
# often not desribed at all

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# STEP 1
# Define file paths
input_file="$BASEFOLDER/geonetwork_records_urls_wide.csv"
output_file="$BASEFOLDER/step1.csv"

# Create the output file (empty initially)
> "$output_file"

# Read the input file line by line
while IFS='$' read -r col1 col2 col3 col4 _; do
    # Skip the line if the last column is empty
    if [ -z "$col4" ]; then
        continue
    fi

    # Initialize the additional field (default to "OTHER")
    additional_field="OTHER"

    # Check for the presence of substrings "wms", "wfs", "wcs", "ows" in the URL (case insensitive)
    if echo "$col4" | grep -iq "wms"; then
        additional_field="WMS"
    elif echo "$col4" | grep -iq "wfs"; then
        additional_field="WFS"
    elif echo "$col4" | grep -iq "wcs"; then
        additional_field="WCS"
    elif echo "$col4" | grep -iq "ows"; then
        additional_field="OWS"
    fi

    # If "OWS" and one of the others are found, prioritize "wms", "wfs", or "wcs"
    if echo "$col4" | grep -iq "ows" && (echo "$col4" | grep -iq "wms" || echo "$col4" | grep -iq "wfs" || echo "$col4" | grep -iq "wcs"); then
        if echo "$col4" | grep -iq "wms"; then
            additional_field="WMS"
        elif echo "$col4" | grep -iq "wfs"; then
            additional_field="WFS"
        elif echo "$col4" | grep -iq "wcs"; then
            additional_field="WCS"
        fi
    fi

    # Append the current line with the additional field to the output file
    echo "$col1\$${col2}\$${col3}\$${col4}\$${additional_field}" >> "$output_file"
done < "$input_file"


# STEP 2
input_file="$BASEFOLDER/step1.csv"
output_file="$BASEFOLDER/step2.csv"

> "$output_file"

# Read the input file line by line
while IFS='$' read -r col1 col2 col3 col4 col5; do
    # Initialize the new field (empty by default)
    new_field=""

    # Criteria based on the last column value (col5)
    if [ "$col5" == "OTHER" ]; then
        new_field=""
    elif [ "$col5" == "WMS" ]; then
        new_field="1.3.0"
    elif [ "$col5" == "WFS" ]; then
        # Check for "2.0.0", "1.1.0", or "1.0.0" in col4
        if echo "$col4" | grep -q "2.0.0"; then
            new_field="2.0.0"
        elif echo "$col4" | grep -q "1.1.0"; then
            new_field="1.1.0"
        elif echo "$col4" | grep -q "1.0.0"; then
            new_field="1.0.0"
        else
            new_field="2.0.0"
        fi
    elif [ "$col5" == "OWS" ]; then
        new_field=""
    elif [ "$col5" == "WCS" ]; then
        # Check for "2.0.0", "2.0.1", "1.1.1", or "1.0.0" in col4
        if echo "$col4" | grep -q "2.0.0"; then
            new_field="2.0.0"
        elif echo "$col4" | grep -q "2.0.1"; then
            new_field="2.0.1"
        elif echo "$col4" | grep -q "1.1.1"; then
            new_field="1.1.1"
        elif echo "$col4" | grep -q "1.0.0"; then
            new_field="1.0.0"
        else
            new_field="1.1.1"
        fi
    fi

    # Append the current line with the new field to the output file
    echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${new_field}" >> "$output_file"
done < "$input_file"


# STEP 3
input_file="$BASEFOLDER/step2.csv"
output_file="$BASEFOLDER/step3.csv"

# Temporary file to hold the processed data before sorting
temp_file=$(mktemp)

# Create the output file (empty initially)
> "$temp_file"

# Read the input file line by line
while IFS='$' read -r col1 col2 col3 col4 col5 col6; do
    # Rule 1: if the second to last column is "OTHER", copy the record as it is
    if [ "$col5" == "OTHER" ]; then
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}" >> "$temp_file"

    # Rule 2: if the second to last column is "WMS", copy the record as it is
    elif [ "$col5" == "WMS" ]; then
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}" >> "$temp_file"

    # Rule 3: if the second to last column is "WFS" and last column is "1.0.0", copy as it is
    elif [ "$col5" == "WFS" ] && [ "$col6" == "1.0.0" ]; then
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}" >> "$temp_file"

    # Rule 4: if the second to last column is "WFS" and last column is "1.1.0", copy twice with "1.0.0"
    elif [ "$col5" == "WFS" ] && [ "$col6" == "1.1.0" ]; then
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}" >> "$temp_file"
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.0.0" >> "$temp_file"

    # Rule 5: if the second to last column is "WFS" and last column is "2.0.0", copy thrice with versions "1.1.0" and "1.0.0"
    elif [ "$col5" == "WFS" ] && [ "$col6" == "2.0.0" ]; then
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}" >> "$temp_file"
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.1.0" >> "$temp_file"
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.0.0" >> "$temp_file"

    # Rule 6: if the second to last column is "WCS" and last column is "1.1.1", copy as it is
    elif [ "$col5" == "WCS" ] && [ "$col6" == "1.1.1" ]; then
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}" >> "$temp_file"

    # Rule 7: if the second to last column is "WCS" and last column is "2.0.0", copy twice with "1.1.1"
    elif [ "$col5" == "WCS" ] && [ "$col6" == "2.0.0" ]; then
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}" >> "$temp_file"
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$1.1.1" >> "$temp_file"

    # Rule 8: if the second to last column is "OWS", copy four times with different values
    elif [ "$col5" == "OWS" ]; then
        echo "$col1\$${col2}\$${col3}\$${col4}\$WMS\$1.3.0" >> "$temp_file"
        echo "$col1\$${col2}\$${col3}\$${col4}\$WFS\$2.0.0" >> "$temp_file"
        echo "$col1\$${col2}\$${col3}\$${col4}\$WFS\$1.1.0" >> "$temp_file"
        echo "$col1\$${col2}\$${col3}\$${col4}\$WFS\$1.0.0" >> "$temp_file"
    fi
done < "$input_file"

# Sort the temporary file by the fourth column (col4) and write to the final output file
sort -t'$' -k4,4 "$temp_file" > "$output_file"

# Clean up the temporary file
rm "$temp_file"


# STEP 4
input_file="$BASEFOLDER/step3.csv"
output_file="$BASEFOLDER/geonetwork_records_urls_long_with_type.csv"

> "$output_file"

# Read the input file line by line
while IFS='$' read -r col1 col2 col3 col4 col5 col6; do
    # Rule 1: if the second to last column value is "OTHER", the new column will be empty
    if [ "$col5" == "OTHER" ]; then
        # Copy the record as it is with an empty new column
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}\$" >> "$output_file"
    else
        # Check if the URL in the fourth column contains a "?" symbol
        if [[ "$col4" == *"?"* ]]; then
            # Extract the part before the "?" symbol
            # url_without_query="${col4%%\?*}"

			# Remove trailing "?" if it exists
			url_without_query="${col4%%\?*}"
			if [[ "${col4}" == *"?" ]]; then
				url_without_query="${col4%?}"
			fi
            
            # Check if the "map" parameter exists in the URL
            if [[ "$col4" == *"map="* ]]; then
                # If "map" exists, keep it and append the other parameters
                map_param="${col4#*map=}"
                new_url="${url_without_query}?service=${col5}&version=${col6}&request=GetCapabilities&map=${map_param}"
            else
                # If "map" does not exist, construct the URL as usual
                new_url="${url_without_query}?service=${col5}&version=${col6}&request=GetCapabilities"
            fi
        else
            # If no "?" is found, just append the parameters as usual
            new_url="${col4}?service=${col5}&version=${col6}&request=GetCapabilities"
        fi

        # Copy the record with the new URL in the additional column
        echo "$col1\$${col2}\$${col3}\$${col4}\$${col5}\$${col6}\$${new_url}" >> "$output_file"
    fi
done < "$input_file"

rm "$BASEFOLDER/"step*.csv
echo "Processing complete. Output written to $output_file."
