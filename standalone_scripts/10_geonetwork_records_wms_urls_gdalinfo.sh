#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
NC='\033[0m'

export CPL_CURL_IGNORE_ERROR=YES

[ -e snig_geonetwork_records_wms_gdalinfo_status_codes.csv ] && rm snig_geonetwork_records_wms_gdalinfo_status_codes.csv
[ -e snig_geonetwork_records_wms_layers.csv ] && rm snig_geonetwork_records_wms_layers.csv

INPUT=snig_geonetwork_records_wms_urls_check_capabilities.csv
OLDIFS=$IFS
IFS=$
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
while read field1 field2 field3 field4 field5 field6 field7
do

    if [ "$field6" = "ok" ]; then

        url=$(echo "$field4" | cut -f1 -d"?" | sed -r 's/http:\/\///g' |  sed -r 's/https:\/\///g' |  sed -r 's/\//_/g' | sed -r 's/\./_/g')


        if [[ "${field4,,}" == *version=1.3.0* ]]; then
            #declare -a version_underscore=("1_3_0" "1_1_1")
            declare -a version_underscore=("1_3_0")
        else
            declare -a version_underscore=("1_1_1")
        fi


        echo -e "${YELLOW}Downloading GDAL WMS infos for record $field1 / $field2 / $field3${NC}"
        echo -e "Original URL: ${YELLOW}$field7${NC}"


        for version in "${version_underscore[@]}"
        do


            if [[ "$version" = 1_3_0 ]]; then
                version_dot=1.3.0
            else
                version_dot=1.1.1
            fi
            

			echo -e "${GREEN}Downloading GDAL response in standard format for version $version_dot${NC}"


            if [[ "$version" = 1_3_0 ]]; then
                gdal_url=$field4
            else
                gdal_url=$(echo "$field4" | sed -r 's/1.3.0/1.1.1/g')
            fi

            echo -e "Request URL: ${YELLOW}$gdal_url${NC}"




#########
						if [ ! -d "WMS_TEMP/$url" ]; then
						    mkdir WMS_TEMP/"$url"
                            gdalinfo "WMS:${gdal_url}" > WMS_TEMP/"$url"/info_"$url"_"$version".txt 2>&1
                            cp WMS_TEMP/"$url"/info_"$url"_"$version".txt WMS/"$field1"/
                        elif [ -d "WMS_TEMP/$url" ] && [ ! -f "WMS_TEMP/"$url"/info_"$url"_"$version".txt" ]; then
                            gdalinfo "WMS:${gdal_url}" > WMS_TEMP/"$url"/info_"$url"_"$version".txt 2>&1
                            cp WMS_TEMP/"$url"/info_"$url"_"$version".txt WMS/"$field1"/
                        else
                            cp WMS_TEMP/"$url"/info_"$url"_"$version".txt WMS/"$field1"/
						fi
#########


            #gdalinfo "WMS:${gdal_url}" > WMS/"$field1"/info_"$url"_"$version".txt 2>&1

            info_start=$(sed -n '1{/^Driver:/p};q' WMS/"$field1"/info_"$url"_"$version".txt)

		    if grep -R -q "Driver: WMS/OGC Web Map Service" WMS/"$field1"/info_"$url"_"$version".txt
		    then
			        if [ -z "$info_start" ] || [[ $(<WMS/"$field1"/info_"$url"_"$version".txt) == *ServiceExceptionReport* ]] || [[ $(<WMS/"$field1"/info_"$url"_"$version".txt) == *ERROR* ]];
			        then
				        gdalinfo_code="${ORANGE}ok (errors or warnings)${NC}"    
			        else
				        gdalinfo_code="${GREEN}ok${NC}"
                    fi
            else
                        gdalinfo_code="${RED}error${NC}"
		    fi


		    echo -e "$gdalinfo_code"
		    gdalinfo_code_no_color=$(echo "$gdalinfo_code" | sed -r 's/\033\[0;32m//g' |  sed -r 's/\033\[0m//g' |  sed -r 's/\033\[0;31m//g' | sed -r 's/\033\[0;33m//g' | sed -r 's/\033\[1;33m//g'  | sed -r 's/\\//g')

		    if [[ "$gdalinfo_code_no_color" == *"ok"* ]]; then

			    success="true"
			    
			    echo -e "${GREEN}Downloading GDAL response in JSON format for version $version_dot${NC}"
                echo -e "Request URL: ${YELLOW}$gdal_url${NC}"



#########
						if [ -f "WMS_TEMP/"$url"/info_"$url"_"$version".json" ]; then
                            cp WMS_TEMP/"$url"/info_"$url"_"$version".json WMS/"$field1"/
                        else
                            gdalinfo -json "WMS:${gdal_url}" > WMS_TEMP/"$url"/info_"$url"_"$version".json 2> /dev/null
                            cp WMS_TEMP/"$url"/info_"$url"_"$version".json WMS/"$field1"/
						fi
#########


			    #gdalinfo -json "WMS:${gdal_url}" > WMS/"$field1"/info_"$url"_"$version".json 2> /dev/null

                xmlstarlet fo -D WMS/"$field1"/wms_capabilities_"$url".xml > WMS/"$field1"/wms_capabilities_temp.xml
                sed -i 's/xmlns=\"http:\/\/www.opengis.net\/wms\"//g' WMS/"$field1"/wms_capabilities_temp.xml
			    sed -i 's/sld://g' WMS/"$field1"/wms_capabilities_temp.xml
                sed -i 's/ms://g' WMS/"$field1"/wms_capabilities_temp.xml

			    SERVICE_TITLE=$(xmlstarlet sel -t -m "//Service" -v "Title" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_ABSTRACT=$(xmlstarlet sel -t -m "//Service" -v "normalize-space(Abstract)" -n WMS/"$field1"/wms_capabilities_temp.xml)
                SERVICE_ABSTRACT="$(echo "$SERVICE_ABSTRACT" | sed 's/\r//' | sed ':a;N;$!ba;s/\n/ /g')"
			    SERVICE_NAME=$(xmlstarlet sel -t -m "//Service" -v "Name" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_KEYWORDS=$(xmlstarlet sel -t -m "//Service" -v "normalize-space(KeywordList)" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_PERSON=$(xmlstarlet sel -t -m "//Service" -v "ContactInformation/ContactPersonPrimary/ContactPerson" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_ORGANIZATION=$(xmlstarlet sel -t -m "//Service" -v "ContactInformation/ContactPersonPrimary/ContactOrganization" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_ADDRESS=$(xmlstarlet sel -t -m "//Service" -v "ContactInformation/ContactAddress/Address" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_CITY=$(xmlstarlet sel -t -m "//Service" -v "ContactInformation/ContactAddress/City" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_COUNTRY=$(xmlstarlet sel -t -m "//Service" -v "ContactInformation/ContactAddress/Country" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_EMAIL=$(xmlstarlet sel -t -m "//Service" -v "ContactInformation/ContactElectronicMailAddress" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_LAYER_TITLE=$(xmlstarlet sel -t -v "//Capability/Layer/Title" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_LAYER_ABSTRACT=$(xmlstarlet sel -t -v "normalize-space(//Capability/Layer/Abstract)" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_LAYER_NAME=$(xmlstarlet sel -t -v "//Capability/Layer/Name" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_LAYER_BBOX=$(xmlstarlet sel -t -v "normalize-space(//Capability/Layer/EX_GeographicBoundingBox)" -n WMS/"$field1"/wms_capabilities_temp.xml)
			    SERVICE_LAYER_CRS=$(xmlstarlet sel -t -v "//Capability/Layer/CRS[1]" -m '//Capability/Layer/CRS[position()>1]' -o ' ' -v . -b -n WMS/"$field1"/wms_capabilities_temp.xml)

                echo "Title:" $SERVICE_TITLE
                echo "Abstract:" $SERVICE_ABSTRACT
                echo "Name:" $SERVICE_NAME

        		record="$SERVICE_TITLE""$""$SERVICE_ABSTRACT""$""$SERVICE_NAME""$""$SERVICE_KEYWORDS""$""$SERVICE_PERSON""$""$SERVICE_ORGANIZATION""$""$SERVICE_ADDRESS""$""$SERVICE_CITY""$""$SERVICE_COUNTRY""$""$SERVICE_EMAIL""$""$SERVICE_LAYER_TITLE""$""$SERVICE_LAYER_ABSTRACT""$""$SERVICE_LAYER_NAME""$""$SERVICE_LAYER_BBOX""$""$SERVICE_LAYER_CRS"
        		echo "$record" > WMS/"$field1"/service_title_abstract_"$url"_"$version".csv

                xmlstarlet sel -T -t -m "//Layer/Layer" -v "Name" -o "$" -v "Title" -o "$" -v "normalize-space(Abstract)" -o "$" -v "normalize-space(KeywordList)" -o "$" -v "normalize-space(EX_GeographicBoundingBox)" -o "$" -v "CRS[1]" -m 'CRS[position()>1]' -o ' ' -v . -b -n WMS/"$field1"/wms_capabilities_temp.xml > layers_list_temp.csv
			   			    
			    [ -e WMS/"$field1"/service_layers_"$url"_"$version".csv ] && rm WMS/"$field1"/service_layers_"$url"_"$version".csv

                echo "Layers:"
			    
			    INPUT=layers_list_temp.csv
			    OLDIFS=$IFS
			    IFS=$
			    [ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
			    while read l_name l_title l_abstract l_keywords l_bbox l_crs
			    do

                echo $l_title

			    layer_record="$field1""$""$field2""$""$field3""$""$gdal_url""$""$version_dot""$""$SERVICE_TITLE""$""$SERVICE_ABSTRACT""$""$SERVICE_LAYER_BBOX""$""$SERVICE_LAYER_CRS""$""$l_name""$""$l_title""$""$l_abstract""$""$l_keywords""$""$l_bbox""$""$l_crs"
			    echo "$layer_record" >> WMS/"$field1"/service_layers_"$url"_"$version".csv
			    echo "$layer_record" >> snig_geonetwork_records_wms_layers.csv
		    
			    done < $INPUT
			    IFS=$OLDIFS

                rm WMS/"$field1"/wms_capabilities_temp.xml
                rm layers_list_temp.csv

		    else
			    success="false"
			    SERVICE_ABSTRACT="N/A"
			    SERVICE_TITLE="N/A"
			    SERVICE_NAME="N/A"
			    SERVICE_KEYWORDS="N/A"
			    SERVICE_PERSON="N/A"
			    SERVICE_ORGANIZATION="N/A"
			    SERVICE_ADDRESS="N/A"
			    SERVICE_CITY="N/A"
			    SERVICE_COUNTRY="N/A"
			    SERVICE_EMAIL="N/A"
			    SERVICE_LAYER_TITLE="N/A"
			    SERVICE_LAYER_ABSTRACT="N/A"
			    SERVICE_LAYER_NAME="N/A"
			    SERVICE_LAYER_BBOX="N/A"
			    SERVICE_LAYER_CRS="N/A"
		    fi

        		record="$field1""$""$field2""$""$field3""$""$gdal_url""$""$SERVICE_TITLE""$""$SERVICE_ABSTRACT""$""$SERVICE_NAME""$""$SERVICE_KEYWORDS""$""$SERVICE_PERSON""$""$SERVICE_ORGANIZATION""$""$SERVICE_ADDRESS""$""$SERVICE_CITY""$""$SERVICE_COUNTRY""$""$SERVICE_EMAIL""$""$SERVICE_LAYER_TITLE""$""$SERVICE_LAYER_ABSTRACT""$""$SERVICE_LAYER_NAME""$""$SERVICE_LAYER_BBOX""$""$SERVICE_LAYER_CRS""$""$gdalinfo_code_no_color""$""$success"
        		echo "$record" >> snig_geonetwork_records_wms_gdalinfo_status_codes.csv

        done

    fi

                printf "\n"
                printf "\n"
                printf "\n"


done < $INPUT
IFS=$OLDIFS
