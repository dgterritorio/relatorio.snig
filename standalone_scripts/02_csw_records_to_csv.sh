#!/bin/bash

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Remove existing files
rm -f "$BASEFOLDER/CSW_RECORDS_CSV/"*.csv

# Ensure necessary directory exists
mkdir -p "$BASEFOLDER/CSW_RECORDS_CSV"

FILES="$BASEFOLDER/CSW_RECORDS/*.xml"
for f in $FILES
do
    filename="$(basename -- $f)"
    filename_no_ext="${filename%.*}"

    echo "Processing $filename"

    xmlstarlet select \
        -N dc="http://purl.org/dc/elements/1.1/" \
        -N csw="http://www.opengis.net/cat/csw/2.0.2" \
        -N dct="http://purl.org/dc/terms/" \
        -N ows="http://www.opengis.net/ows" \
        -N geonet="http://www.fao.org/geonetwork" \
        -N xsi="http://www.w3.org/2001/XMLSchema-instance" \
        -T -t \
        -m "//csw:Record" \
        -v "dc:identifier" -o '$' \
        -v "dc:date" -o '$' \
        --var linebreak -n --break \
        -v "translate(dc:title, \$linebreak ,'@')" -o '$' \
        -v "dc:type" -o '$' \
        -m "dc:subject" -v "concat(.,',')" -b -o '$' \
        -m "dc:format" -v "concat(.,',')" -b -o '$' \
        -m "dct:modified" -v "concat(.,',')" -b -o '$' \
        -v "translate(dct:abstract, \$linebreak ,'@')" -o '$' \
        -v "translate(dc:description, \$linebreak ,'@')" -o '$' \
        -m "dc:rights" -v "concat(.,',')" -b -o '$' \
        -m "dc:language" -v "concat(.,',')" -b -o '$' \
        -v "translate(dc:source, \$linebreak ,'@')" -o '$' \
        -v "dc:URI[1]" -o '$' \
        -v "dc:URI[2]" -o '$' \
        -v "dc:URI[3]" -o '$' \
        -v "ows:BoundingBox[1]/@crs" -o '$' \
        -v "ows:BoundingBox[1]/ows:LowerCorner[1]" -o '$' \
        -v "ows:BoundingBox[1]/ows:UpperCorner[1]" -o '$' \
        -v "ows:BoundingBox[2]/@crs" -o '$' \
        -v "ows:BoundingBox[2]/ows:LowerCorner[1]" -o '$' \
        -v "ows:BoundingBox[2]/ows:UpperCorner[1]" -o '$' \
        -v "ows:BoundingBox[3]/@crs" -o '$' \
        -v "ows:BoundingBox[3]/ows:LowerCorner[1]" -o '$' \
        -v "ows:BoundingBox[3]/ows:UpperCorner[1]" -o '$' \
        -v "ows:BoundingBox[4]/@crs" -o '$' \
        -v "ows:BoundingBox[4]/ows:LowerCorner[1]" -o '$' \
        -v "ows:BoundingBox[4]/ows:UpperCorner[1]" -n \
        "$BASEFOLDER/CSW_RECORDS/$filename" > "$BASEFOLDER/CSW_RECORDS_CSV/$filename_no_ext.csv"

done

# Combine all CSV files into one
cat "$BASEFOLDER/CSW_RECORDS_CSV/"csw_records_*.csv > "$BASEFOLDER/CSW_RECORDS_CSV/"csw_records_csv.csv
