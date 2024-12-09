#!/bin/bash

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Export the variables so that it's available in the parallel processes
export BASEFOLDER
export SCRIPT_DIR

# Remove existing files
rm -f "$BASEFOLDER/CSW_RECORDS/*.xml"
# Ensure necessary directory exists
mkdir -p "$BASEFOLDER/CSW_RECORDS"

# Function to process each chunk
process_chunk() {
    local start="$1"
    local step=10

    echo "Processing $step records starting at $start"

    # Unique payload file for this chunk
    local payload_file="download_csw_records_payload_${start}.txt"

    # Prepare payload file
    cp "$SCRIPT_DIR/01_download_csw_records_payload_template.txt" "$BASEFOLDER/$payload_file"
    sed -i 's/XXX/'$start'/' "$BASEFOLDER/$payload_file"
    sed -i 's/YYY/'$step'/' "$BASEFOLDER/$payload_file"

    # Make the HTTP request and save the output
    curl -X POST --header "Content-Type:text/xml;charset=UTF-8" --data @"$BASEFOLDER/$payload_file" \
        "https://snig.dgterritorio.gov.pt/rndg/srv/por/csw?request=GetRecords&service=CSW" \
        -o "$BASEFOLDER/CSW_RECORDS/csw_records_${start}_$((start + step)).xml"

    # Harvest also the ISPIRE catalog
    curl -X POST --header "Content-Type:text/xml;charset=UTF-8" --data @"$BASEFOLDER/$payload_file" \
        "https://snig.dgterritorio.gov.pt/rndg/srv/eng/csw-inspire?request=GetRecords&service=CSW" \
        -o "$BASEFOLDER/CSW_RECORDS/csw_records_inspire_${start}_$((start + step)).xml"

    # Cleanup temporary file
    rm -f "$BASEFOLDER/$payload_file"
}

# Export the function for use with GNU parallel
export -f process_chunk

# Remove existing files
#rm -f download_csw_records_payload_*.txt

# Generate sequence of starting indices and run in parallel
seq 1 10 18000 | parallel --jobs 4 process_chunk {}
