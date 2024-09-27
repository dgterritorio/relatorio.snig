#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
NC='\033[0m'

#rm -R WMS/*

[ -e snig_geonetwork_records_wms_urls_check_capabilities.csv ] && rm snig_geonetwork_records_wms_urls_check_capabilities.csv

INPUT=snig_geonetwork_records_urls_status_codes.csv
OLDIFS=$IFS
IFS=$
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }

while read field1 field2 field3 field4 field5
do

if [ "$field5" = "200" ]; then

				if [[ "${field4,,}" == *wms* ]] || [[ "${field4,,}" == *wms ]]; then

                    echo -e "${YELLOW}URL seems WMS, downloading capabilities for record $field1 / $field2 / $field3${NC}"

					base_url=$(echo "$field4" | sed -r 's/\?service=WMS//gI' | sed -r 's/service=WMS//gI' | sed -r 's/\?version=1.3.0//gI' | sed -r 's/version=1.3.0//gI' |  sed -r 's/&//g' | sed -r 's/\?request=GetCapabilities//gI' | sed -r 's/request=GetCapabilities//gI' | sed -r 's/\?version=1.1.1//gI' | sed -r 's/version=1.1.1//gI' | sed 's/\(?\)*$//g')
                    service="?service=WMS"
                    request="&request=GetCapabilities"

                        version="&version=1.3.0"

    		        wms_url=$base_url$service$request$version
                    
                    echo "Original URL:" $field4
                    echo "Request URL:" $wms_url

						if [ ! -d "WMS/$field1" ]; then
						    mkdir WMS/"$field1"
						fi
										
					url=$(echo "$field4" | cut -f1 -d"?" | sed -r 's/http:\/\///g' |  sed -r 's/https:\/\///g' |  sed -r 's/\//_/g' | sed -r 's/\./_/g')
					
                    curl -L "${wms_url}" > WMS/"$field1"/"$url".xml

						if ! [ -s WMS/"$field1"/"$url".xml ]; then
						    echo -e "${RED}Download of WMS capabilities with cURL failed, trying again with WGET${NC}"
						    wget "${wms_url}" -O WMS/"$field1"/"$url".xml
                        fi
											
						if ! [ -s WMS/"$field1"/"$url".xml ]; then
						    echo -e "${RED}Download of WMS capabilities with WGET failed, skipping${NC}"
							status_code="failed"
                        else
									
						if xmlstarlet val WMS/"$field1"/"$url".xml | grep -w -q 'valid'; then
											
							if grep -q 'Error 404' WMS/"$field1"/"$url".xml || grep -q 'ERROR 404' WMS/"$field1"/"$url".xml || grep -q 'validation failed' WMS/"$field1"/"$url".xml || grep -q '<BODY>' WMS/"$field1"/"$url".xml || grep -q '<body>' WMS/"$field1"/"$url".xml || grep -q 'Server Error' WMS/"$field1"/"$url".xml || grep -q 'File or directory not found' WMS/"$field1"/"$url".xml || grep -q 'Moved Permanently' WMS/"$field1"/"$url".xml; then
												
							    echo -e "${RED}WMS capabilities seems to have issues${NC}"
								status_code="error"
								mv WMS/"$field1"/"$url".xml WMS/"$field1"/error_"$url".html												
												
							else
											
								echo -e "${GREEN}WMS capabilities seems OK${NC}"
								status_code="ok"
		    					xmllint --format WMS/"$field1"/"$url".xml > WMS/"$field1"/wms_capabilities_"$url".xml
								rm WMS/"$field1"/"$url".xml
											
							fi
											
						else
											
							    echo -e "${RED}WMS capabilities seems to have issues${NC}"
								status_code="error"
								mv WMS/"$field1"/"$url".xml WMS/"$field1"/error_"$url".html
											
						fi
											
					    echo "[{000214A0-0000-0000-C000-000000000046}]" > WMS/"$field1"/"$field1".url
                        echo "Prop3=19,2" >> WMS/"$field1"/"$field1".url
                        echo "[InternetShortcut]" >> WMS/"$field1"/"$field1".url
                        echo "IDList=" >> WMS/"$field1"/"$field1".url
                        echo "URL=https://snig.dgterritorio.gov.pt/rndg/srv/por/catalog.search#/metadata/$field1" >> WMS/"$field1"/"$field1".url
															
						record="$field1""$""$field2""$""$field3""$""${wms_url}""$""$field5""$""$status_code""$""$field4"
                        echo "$record" >> snig_geonetwork_records_wms_urls_check_capabilities.csv
   
                        fi
										
				fi            

fi 


done < $INPUT
IFS=$OLDIFS


find WMS/ -type d -empty -delete
