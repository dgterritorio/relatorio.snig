#!/bin/bash

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Export the variables so that it's available in the parallel processes
export BASEFOLDER
export SCRIPT_DIR

# Remove existing files
rm -f "$BASEFOLDER/SNIG_GEONETWORK_METADATA/"*.xml
# Ensure necessary directory exists
mkdir -p "$BASEFOLDER/SNIG_GEONETWORK_METADATA"

# Function to download metadata
download_metadata() {
  local uuid=$1
  echo "Downloading SNIG/GEONETWORK metadata for record $uuid"
  wget "https://snig.dgterritorio.gov.pt/rndg/srv/api/records/$uuid/formatters/xml" -O "$BASEFOLDER/SNIG_GEONETWORK_METADATA/$uuid.xml"
}

export -f download_metadata  # Export the function for parallel

# Read the CSV and run the download function in parallel with a maximum of 4 concurrent jobs
cat "$BASEFOLDER/CSW_RECORDS_CSV/csw_records_csv.csv" | cut -d"$" -f1 | parallel -j 4 download_metadata
