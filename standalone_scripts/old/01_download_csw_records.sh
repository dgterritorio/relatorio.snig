#!/bin/bash
BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [ "$1" == "identify" ]; then
    echo "{CWSCheck} {compare CSW records to template}"
    exit 0
fi

rm $BASEFOLDER/CSW_RECORDS/*.xml
mkdir -p $BASEFOLDER/CSW_RECORDS

i=1
step=500

until [ $i -gt 18000 ]
do

    echo "Processing $step records starting at $i"

    cp $SCRIPT_DIR/01_download_csw_records_payload_template.txt $SCRIPT_DIR/download_csw_records_payload.txt
    sed -i 's/XXX/'$i'/' $SCRIPT_DIR/download_csw_records_payload.txt
    sed -i 's/YYY/'$step'/' $SCRIPT_DIR/download_csw_records_payload.txt

    curl -X POST --header "Content-Type:text/xml;charset=UTF-8" --data @download_csw_records_payload.txt "https://snig.dgterritorio.gov.pt/rndg/srv/por/csw?request=GetRecords&se>
    ((i=i+$step))

done

rm $SCRIPT_DIR/download_csw_records_payload.txt
