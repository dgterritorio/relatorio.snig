#!/bin/bash

rm SNIG_GEONETWORK_METADATA/*.xml

while IFS="$" read -r uuid other_fields
do

if [ -e SNIG_GEONETWORK_METADATA/$uuid.xml ]; then

	if [ -s SNIG_GEONETWORK_METADATA/$uuid.xml ]; then

	echo "Metadata file already exists and has not 0 size, skipping"

	else

 	echo "Re-Downloading SNIG/GEONETWORK metadata for record $uuid"
  	wget "https://snig.dgterritorio.gov.pt/rndg/srv/api/records/$uuid/formatters/xml" -O "SNIG_GEONETWORK_METADATA/$uuid.xml"

	fi

else

  echo "Downloading SNIG/GEONETWORK metadata for record $uuid"
  wget "https://snig.dgterritorio.gov.pt/rndg/srv/api/records/$uuid/formatters/xml" -O "SNIG_GEONETWORK_METADATA/$uuid.xml"

fi

done < CSW_RECORDS_CSV/csw_records_csv.csv
