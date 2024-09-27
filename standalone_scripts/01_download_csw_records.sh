#!/bin/bash

rm CSW_RECORDS/*.xml

i=1
step=500

until [ $i -gt 18000 ]
do

    echo "Processing $step records starting at $i"

    cp 01_download_csw_records_payload_template.txt download_csw_records_payload.txt
    sed -i 's/XXX/'$i'/' download_csw_records_payload.txt
    sed -i 's/YYY/'$step'/' download_csw_records_payload.txt

    curl -X POST --header "Content-Type:text/xml;charset=UTF-8" --data @download_csw_records_payload.txt "https://snig.dgterritorio.gov.pt/rndg/srv/por/csw?request=GetRecords&service=CSW" -o "CSW_RECORDS/csw_records_"$i"_"$((i+step))".xml"

    ((i=i+$step))

done

rm download_csw_records_payload.txt
