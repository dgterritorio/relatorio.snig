#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
NC='\033[0m'

rm -R WCS/*

[ -e snig_geonetwork_records_wcs_urls_check_capabilities.csv ] && rm snig_geonetwork_records_wcs_urls_check_capabilities.csv

INPUT=snig_geonetwork_records_urls_status_codes.csv
OLDIFS=$IFS
IFS=$
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }

while read field1 field2 field3 field4 field5
do

if [ "$field5" = "200" ]; then

				if [[ "${field4,,}" == *wcs* ]] || [[ "${field4,,}" == *wcs ]]; then

                    echo -e "${YELLOW}URL seems WCS, downloading capabilities for record $field1 / $field2 / $field3${NC}"

					base_url=$(echo "$field4" | sed -r 's/\?service=WCS//gI' | sed -r 's/service=WCS//gI' | sed -r 's/\?version=2.0.0//gI' | sed -r 's/version=2.0.0//gI' |  sed -r 's/&//g' | sed -r 's/\?request=GetCapabilities//gI' | sed -r 's/request=GetCapabilities//gI' | sed 's/\(?\)*$//g')
                    service="?service=WCS"
                    request="&request=GetCapabilities"

                    if [[ "$field4" == *2.0.0* ]]; then  
                        version="&version=2.0.1"
                    else 
                        version="&version=1.1.1"
                    fi

    		        wcs_url=$base_url$service$request$version
                    
                    echo $field4
                    echo $wcs_url

						if [ ! -d "WCS/$field1" ]; then
						    mkdir WCS/"$field1"
						fi
										
					url=$(echo "$field4" | cut -f1 -d"?" | sed -r 's/http:\/\///g' |  sed -r 's/https:\/\///g' |  sed -r 's/\//_/g' | sed -r 's/\./_/g')
					
                    curl -L "${wcs_url}" > WCS/"$field1"/"$url".xml

						if ! [ -s WCS/"$field1"/"$url".xml ]; then
						    echo -e "${RED}Download of WCS capabilities with cURL failed, trying again with WGET${NC}"
						    wget "${wcs_url}" -O WCS/"$field1"/"$url".xml
                        fi
											
						if ! [ -s WCS/"$field1"/"$url".xml ]; then
						    echo -e "${RED}Download of WCS capabilities with WGET failed, skipping${NC}"
							status_code="failed"
                        else
									
						if xmlstarlet val WCS/"$field1"/"$url".xml | grep -w -q 'valid'; then
											
							if grep -q 'Error 404' WCS/"$field1"/"$url".xml || grep -q 'ERROR 404' WCS/"$field1"/"$url".xml || grep -q '<body>' WCS/"$field1"/"$url".xml || grep -q 'Server Error' WCS/"$field1"/"$url".xml || grep -q 'File or directory not found' WCS/"$field1"/"$url".xml || grep -q 'Moved Permanently' WCS/"$field1"/"$url".xml; then
												
							    echo -e "${RED}WCS capabilities seems to have issues${NC}"
								status_code="error"
								mv WCS/"$field1"/"$url".xml WCS/"$field1"/error_"$url".html												
												
							else
											
								echo -e "${GREEN}WCS capabilities seems OK${NC}"
								status_code="ok"
		    					xmllint --format WCS/"$field1"/"$url".xml > WCS/"$field1"/wcs_capabilities_"$url".xml
								rm WCS/"$field1"/"$url".xml
											
							fi
											
						else
											
							    echo -e "${RED}WCS capabilities seems to have issues${NC}"
								status_code="error"
								mv WCS/"$field1"/"$url".xml WCS/"$field1"/error_"$url".html
											
						fi
											
					    echo "[{000214A0-0000-0000-C000-000000000046}]" > WCS/"$field1"/"$field1".url
                        echo "Prop3=19,2" >> WCS/"$field1"/"$field1".url
                        echo "[InternetShortcut]" >> WCS/"$field1"/"$field1".url
                        echo "IDList=" >> WCS/"$field1"/"$field1".url
                        echo "URL=https://snig.dgterritorio.gov.pt/rndg/srv/por/catalog.search#/metadata/$field1" >> WCS/"$field1"/"$field1".url
															
						record="$field1""$""$field2""$""$field3""$""${wcs_url}""$""$field5""$""$status_code""$""$field4"
                        echo "$record" >> snig_geonetwork_records_wcs_urls_check_capabilities.csv
   
                        fi
										
				fi            

fi 


done < $INPUT
IFS=$OLDIFS


find WCS/ -type d -empty -delete
