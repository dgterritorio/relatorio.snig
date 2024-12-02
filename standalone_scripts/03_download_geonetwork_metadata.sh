#!/bin/bash

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Remove existing files
rm -f "$BASEFOLDER/SNIG_GEONETWORK_METADATA/"*.xml
# Ensure necessary directory exists
mkdir -p "$BASEFOLDER/SNIG_GEONETWORK_METADATA"

while IFS="$" read -r uuid other_fields
do

#if [ -e "$BASEFOLDER/SNIG_GEONETWORK_METADATA/$uuid.xml" ]; then
#       if [ -s "$BASEFOLDER/SNIG_GEONETWORK_METADATA/$uuid.xml" ]; then
#       echo "Metadata file already exists and has not 0 size, skipping"
#               else
#       echo "Re-Downloading SNIG/GEONETWORK metadata for record $uuid"
#       wget "https://snig.dgterritorio.gov.pt/rndg/srv/api/records/$uuid/formatters/xml" -O "SNIG_GEONETWORK_METADATA/$uuid.xml"
#       fi
#else
  echo "Downloading SNIG/GEONETWORK metadata for record $uuid"
  wget "https://snig.dgterritorio.gov.pt/rndg/srv/api/records/$uuid/formatters/xml" -O "$BASEFOLDER/SNIG_GEONETWORK_METADATA/$uuid.xml"
#fi

done < "$BASEFOLDER/CSW_RECORDS_CSV/csw_records_csv.csv"
