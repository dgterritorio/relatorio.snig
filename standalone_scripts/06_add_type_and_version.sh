#!/bin/bash

# This script will take the CSV, in \"long\" format, that contains the harvested services URLs
# and will generate a copy of the same fiel were the URLs have been \"sanitized\" and where the protool version and type
# are also added, because frequentely the service URLs in metadata are not well written and version and protocal type are
# often not desribed at all.
# This will make the original list longer, because services URLs that are defined as \"OWS\" will be tested for both WMS and WFS,
# WFS services declared as \"2.0.0\" will be tested also for \"1.1.0\" and \"1.0.0\" and so on.

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Input file
input_file="$BASEFOLDER/geonetwork_records_urls_long.csv"

# Output file
output_file="$BASEFOLDER/geonetwork_records_urls_long_with_type.csv"

# Temporary file to store unique records based on the 4th, 5th, and 6th fields
temp_file=$(mktemp)

# Step 1: Remove duplicate rows based on the 4th, 5th, and 6th fields
awk -F'$' '!seen[$4 FS $5 FS $6]++' "$input_file" > "$temp_file"

# Step 2: Process the file after duplicates have been removed
awk -F'$' '{
    # Convert the 4th field to lowercase for easier matching
    url = tolower($4);

    # Initialize the 5th, 6th, and 7th fields to empty
    fifth_field = "";
    sixth_field = "";
    seventh_field = "";

    # Check if the 4th field contains WFS, WMS, WCS, or OWS (case-insensitive)
    if (url ~ /wfs/) {
        fifth_field = "WFS";

        # Check if the URL contains "version="
        if (url ~ /version=([0-9]+\.[0-9]+\.[0-9]+)/) {
            match(url, /version=([0-9]+\.[0-9]+\.[0-9]+)/, arr);
            sixth_field = arr[1];
        } else {
            sixth_field = "2.0.0";  # Default to 2.0.0 if no version is found
        }
    } else if (url ~ /wms/) {
        fifth_field = "WMS";

        # Check if the URL contains "version="
        if (url ~ /version=([0-9]+\.[0-9]+\.[0-9]+)/) {
            match(url, /version=([0-9]+\.[0-9]+\.[0-9]+)/, arr);
            sixth_field = arr[1];
        } else {
            sixth_field = "1.3.0";  # Default to 1.3.0 if no version is found
        }
    } else if (url ~ /wcs/) {
        fifth_field = "WCS";
        sixth_field = "2.0.0";  # WCS default version
    } else if (url ~ /ows/) {
        fifth_field = "OWS";
        sixth_field = "";  # No version for OWS
    } else if (length($4) > 0) {
        fifth_field = "other";
        sixth_field = "";  # No version for "other"
    }

    # Check if we need to construct the 7th field for WFS, WMS, or WCS
    if (fifth_field == "WFS" || fifth_field == "WMS" || fifth_field == "WCS") {
        seventh_field = $4;  # Start with the original URL from the 4th field

        # Check if the URL already has "service=", "version=", or "request="
        if (seventh_field !~ /service=/) {
            seventh_field = seventh_field ((seventh_field ~ /\?/) ? "&" : "?") "service=" fifth_field;
        }
        if (seventh_field !~ /version=/) {
            seventh_field = seventh_field "&version=" sixth_field;
        }
        if (seventh_field !~ /request=/) {
            seventh_field = seventh_field "&request=GetCapabilities";
        }
    } else {
        seventh_field = "";  # No 7th field for non-WFS/WMS/WCS
    }

    # Output the original fields with the new 5th, 6th, and 7th fields
    print $1 FS $2 FS $3 FS $4 FS fifth_field FS sixth_field FS seventh_field;

    # Duplication logic
    if (fifth_field == "WFS" && sixth_field == "2.0.0") {
        # Duplicate WFS record with version 1.1.0
        new_seventh_field = seventh_field;
        gsub("version=2.0.0", "version=1.1.0", new_seventh_field);  # Adjust version in the URL
        print $1 FS $2 FS $3 FS $4 FS fifth_field FS "1.1.0" FS new_seventh_field;
    }

    if (fifth_field == "OWS") {
        # Create a new row with WMS and version 1.3.0
        print $1 FS $2 FS $3 FS $4 FS "WMS" FS "1.3.0" FS $4 "?service=WMS&version=1.3.0&request=GetCapabilities";

        # Create another row with WFS and version 1.1.0
        print $1 FS $2 FS $3 FS $4 FS "WFS" FS "1.1.0" FS $4 "?service=WFS&version=1.1.0&request=GetCapabilities";
    }
}' "$temp_file" > "$output_file"

# Remove temporary file
rm "$temp_file"

echo "Output saved to $output_file"
