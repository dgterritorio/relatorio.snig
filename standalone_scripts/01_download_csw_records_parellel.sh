#!/bin/bash

if [ "$1" == "identify" ]; then
    echo "{CWSCheck} {compare CSW records to template}"
    exit 0
fi

# Ensure necessary directory exists
mkdir -p CSW_RECORDS

# Function to process each chunk
process_chunk() {
    local start="$1"
    local step=10

    echo "Processing $step records starting at $start"

    # Unique payload file for this chunk
    local payload_file="download_csw_records_payload_${start}.txt"

    # Prepare payload file
    cp 01_download_csw_records_payload_template.txt "$payload_file"
    sed -i 's/XXX/'$start'/' "$payload_file"
    sed -i 's/YYY/'$step'/' "$payload_file"

    # Make the HTTP request and save the output
    curl -X POST --header "Content-Type:text/xml;charset=UTF-8" --data @"$payload_file" \
        "https://snig.dgterritorio.gov.pt/rndg/srv/por/csw?request=GetRecords&service=CSW" \
        -o "CSW_RECORDS/csw_records_${start}_$((start + step)).xml"

    # Cleanup temporary file
    rm -f "$payload_file"
}

# Export the function for use with GNU parallel
export -f process_chunk

# Remove existing files
rm -f CSW_RECORDS/*.xml
rm -f download_csw_records_payload_*.txt

# Generate sequence of starting indices and run in parallel
seq 1 50 18000 | parallel --jobs 4 process_chunk {}
