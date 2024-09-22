#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
NC='\033[0m'

rm -R WFS/*

[ -e snig_geonetwork_records_wfs_urls_check_capabilities.csv ] && rm snig_geonetwork_records_wfs_urls_check_capabilities.csv

INPUT=snig_geonetwork_records_urls_status_codes.csv
OLDIFS=$IFS
IFS=$
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }

while read field1 field2 field3 field4 field5
do

if [ "$field5" = "200" ]; then

				if [[ "${field4,,}" == *wfs* ]] || [[ "${field4,,}" == *wfs ]]; then

                    echo -e "${YELLOW}URL seems WFS, downloading capabilities for record $field1 / $field2 / $field3${NC}"

					base_url=$(echo "$field4" | sed -r 's/\?service=WFS//gI' | sed -r 's/service=WFS//gI' | sed -r 's/\?version=2.0.0//gI' | sed -r 's/version=2.0.0//gI' |  sed -r 's/&//g' | sed -r 's/\?request=GetCapabilities//gI' | sed -r 's/request=GetCapabilities//gI' | sed -r 's/\?version=1.1.0//gI' | sed -r 's/version=1.1.0//gI' | sed -r 's/\?version=1.0.0//gI' | sed -r 's/version=1.0.0//gI' | sed 's/\(?\)*$//g')
                    service="?service=WFS"
                    request="&request=GetCapabilities"

                    if [[ "$field4" == *2.0.0* ]]; then  
                        version="&version=2.0.0"
                    elif [[ "$field4" == *1.1.0* ]]; then  
                        version="&version=1.1.0"
                    else 
                        version="&version=1.0.0"
                    fi

    		        wfs_url=$base_url$service$request$version
                    
                    echo $field4
                    echo $wfs_url

						if [ ! -d "WFS/$field1" ]; then
						    mkdir WFS/"$field1"
						fi
										
					url=$(echo "$field4" | cut -f1 -d"?" | sed -r 's/http:\/\///g' |  sed -r 's/https:\/\///g' |  sed -r 's/\//_/g' | sed -r 's/\./_/g')
					
                    curl -L "${wfs_url}" > WFS/"$field1"/"$url".xml

						if ! [ -s WFS/"$field1"/"$url".xml ]; then
						    echo -e "${RED}Download of WFS capabilities with cURL failed, trying again with WGET${NC}"
						    wget "${wfs_url}" -O WFS/"$field1"/"$url".xml
                        fi
											
						if ! [ -s WFS/"$field1"/"$url".xml ]; then
						    echo -e "${RED}Download of WFS capabilities with WGET failed, skipping${NC}"
							status_code="failed"
                        else
									
						if xmlstarlet val WFS/"$field1"/"$url".xml | grep -w -q 'valid'; then
											
							if grep -q 'Error 404' WFS/"$field1"/"$url".xml || grep -q 'ERROR 404' WFS/"$field1"/"$url".xml || grep -q '<body>' WFS/"$field1"/"$url".xml || grep -q 'Server Error' WFS/"$field1"/"$url".xml || grep -q 'File or directory not found' WFS/"$field1"/"$url".xml || grep -q 'Moved Permanently' WFS/"$field1"/"$url".xml; then
												
							    echo -e "${RED}WFS capabilities seems to have issues${NC}"
								status_code="error"
								mv WFS/"$field1"/"$url".xml WFS/"$field1"/error_"$url".html												
												
							else
											
								echo -e "${GREEN}WFS capabilities seems OK${NC}"
								status_code="ok"
		    					xmllint --format WFS/"$field1"/"$url".xml > WFS/"$field1"/wfs_capabilities_"$url".xml
								rm WFS/"$field1"/"$url".xml
											
							fi
											
						else
											
							    echo -e "${RED}WFS capabilities seems to have issues${NC}"
								status_code="error"
								mv WFS/"$field1"/"$url".xml WFS/"$field1"/error_"$url".html
											
						fi
											
					    echo "[{000214A0-0000-0000-C000-000000000046}]" > WFS/"$field1"/"$field1".url
                        echo "Prop3=19,2" >> WFS/"$field1"/"$field1".url
                        echo "[InternetShortcut]" >> WFS/"$field1"/"$field1".url
                        echo "IDList=" >> WFS/"$field1"/"$field1".url
                        echo "URL=https://snig.dgterritorio.gov.pt/rndg/srv/por/catalog.search#/metadata/$field1" >> WFS/"$field1"/"$field1".url
															
						record="$field1""$""$field2""$""$field3""$""${wfs_url}""$""$field4""$""$status_code"
                        echo "$record" >> snig_geonetwork_records_wfs_urls_check_capabilities.csv
   
                        fi
										
				fi            

fi 

done < $INPUT
IFS=$OLDIFS

find WFS/ -type d -empty -delete
