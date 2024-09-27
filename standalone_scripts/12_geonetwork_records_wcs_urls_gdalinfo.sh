#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
NC='\033[0m'

export CPL_CURL_IGNORE_ERROR=YES

[ -e snig_geonetwork_records_wcs_gdalinfo_status_codes.csv ] && rm snig_geonetwork_records_wcs_gdalinfo_status_codes.csv
[ -e snig_geonetwork_records_wcs_layers.csv ] && rm snig_geonetwork_records_wcs_layers.csv

INPUT=snig_geonetwork_records_wcs_urls_check_capabilities.csv
OLDIFS=$IFS
IFS=$
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
while read field1 field2 field3 field4 field5 field6 field7
do

    if [ "$field6" = "ok" ]; then

        url=$(echo "$field4" | cut -f1 -d"?" | sed -r 's/http:\/\///g' |  sed -r 's/https:\/\///g' |  sed -r 's/\//_/g' | sed -r 's/\./_/g')


        if [[ "${field4,,}" == *version=2.0.1* ]]; then
            #declare -a version_underscore=("1_3_0" "1_1_1")
            declare -a version_underscore=("2_0_1")
        else
            declare -a version_underscore=("1_1_1")
        fi


        echo -e "${YELLOW}Downloading GDAL WCS infos for record $field1 / $field2 / $field3${NC}"
        echo -e "Original URL: ${YELLOW}$field7${NC}"


        for version in "${version_underscore[@]}"
        do


            if [[ "$version" = 2_0_1 ]]; then
                version_dot=2.0.1
            else
                version_dot=1.1.1
            fi
            

			echo -e "${GREEN}Downloading GDAL response in standard format for version $version_dot${NC}"


            if [[ "$version" = 2_0_1 ]]; then
                gdal_url=$field4
            else
                gdal_url=$(echo "$field4" | sed -r 's/2.0.1/1.1.1/g')
            fi

            echo -e "Request URL: ${YELLOW}$gdal_url${NC}"
            gdalinfo "WCS:${gdal_url}" > WCS/"$field1"/info_"$url"_"$version".txt 2>&1

            info_start=$(sed -n '1{/^Driver:/p};q' WCS/"$field1"/info_"$url"_"$version".txt)

		    if grep -R -q "Driver: WCS/OGC Web Coverage Service" WCS/"$field1"/info_"$url"_"$version".txt
		    then
			        if [ -z "$info_start" ];
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
			    gdalinfo -json "WCS:${gdal_url}" > WCS/"$field1"/info_"$url"_"$version".json 2> /dev/null

                xmlstarlet fo -D WCS/"$field1"/wcs_capabilities_"$url".xml > WCS/"$field1"/wcs_capabilities_temp.xml
                sed -i 's/xmlns=\"http:\/\/www.opengis.net\/wcs\"//g' WCS/"$field1"/wcs_capabilities_temp.xml
			    sed -i 's/sld://g' WCS/"$field1"/wcs_capabilities_temp.xml
                sed -i 's/ms://g' WCS/"$field1"/wcs_capabilities_temp.xml
                sed -i 's/ows://g' WCS/"$field1"/wcs_capabilities_temp.xml
                sed -i 's/wcs://g' WCS/"$field1"/wcs_capabilities_temp.xml
                sed -i 's/urn:ogc:def:crs://g' WCS/"$field1"/wcs_capabilities_temp.xml
                sed -i 's/crs://g' WCS/"$field1"/wcs_capabilities_temp.xml
                sed -i 's/http:\/\/www.opengis.net\/def\/crs\/EPSG\/0\/EPSG://g' WCS/"$field1"/wcs_capabilities_temp.xml

			    SERVICE_TITLE=$(xmlstarlet sel -t -m "//ServiceIdentification" -v "Title" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_ABSTRACT=$(xmlstarlet sel -t -m "//SerServiceIdentificationvice" -v "normalize-space(Abstract)" -n WCS/"$field1"/wcs_capabilities_temp.xml)
                SERVICE_ABSTRACT="$(echo "$SERVICE_ABSTRACT" | sed 's/\r//' | sed ':a;N;$!ba;s/\n/ /g')"
			    SERVICE_TYPE=$(xmlstarlet sel -t -m "//ServiceIdentification" -v "ServiceType" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_CONSTRAINTS=$(xmlstarlet sel -t -m "//ServiceIdentification" -v "AccessConstraints" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_VERSIONS=$(xmlstarlet sel -t -v "//ServiceIdentification/ServiceTypeVersion[1]" -m '//ServiceIdentification/ServiceTypeVersion[position()>1]' -o ' ' -v . -b -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_KEYWORDS=$(xmlstarlet sel -t -m "//ServiceIdentification" -v "normalize-space(Keywords)" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_PERSON=$(xmlstarlet sel -t -m "//ServiceProvider" -v "ServiceContact/IndividualName" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_PROVIDER=$(xmlstarlet sel -t -m "//ServiceProvider" -v "ProviderName" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_ADDRESS=$(xmlstarlet sel -t -m "//ServiceProvider" -v "ServiceContact/Address/DeliveryPoint" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_CITY=$(xmlstarlet sel -t -m "//ServiceProvider" -v "ServiceContact/Address/City" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_COUNTRY=$(xmlstarlet sel -t -m "//ServiceProvider" -v "ServiceContact/Address/Country" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_EMAIL=$(xmlstarlet sel -t -m "//ServiceMetadata" -v "ServiceContact/Address/ElectronicMailAddress" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_FORMATS=$(xmlstarlet sel -t -m "//ServiceProvider" -v "normalize-space(formatSupported)" -n WCS/"$field1"/wcs_capabilities_temp.xml)
			    SERVICE_CRS=$(xmlstarlet sel -t -m "//ServiceProvider" -v "normalize-space(Extension/CrsMetadata/crsSupported)" -n WCS/"$field1"/wcs_capabilities_temp.xml)

                echo "Title:" $SERVICE_TITLE
                echo "Abstract:" $SERVICE_ABSTRACT

        		record="$SERVICE_TITLE""$""$SERVICE_ABSTRACT""$""$SERVICE_TYPE""$""$SERVICE_KEYWORDS""$""$SERVICE_CONSTRAINTS""$""$SERVICE_VERSIONS""$""$SERVICE_PERSON""$""$SERVICE_PROVIDER""$""$SERVICE_ADDRESS""$""$SERVICE_CITY""$""$SERVICE_COUNTRY""$""$SERVICE_EMAIL""$""$SERVICE_FORMATS""$""$SERVICE_CRS"
        		echo "$record" > WCS/"$field1"/service_title_abstract_"$url"_"$version".csv

                xmlstarlet sel -T -t -m "//Contents/CoverageSummary" -v "Identifier" -o "$" -v "normalize-space(Title)" -o "$" -v "normalize-space(Abstract)" -o "$" -v "normalize-space(Keywords)" -o "$" -v "normalize-space(WGS84BoundingBox)" -o "$" -v "normalize-space(BoundingBox)" -o "$" -v "SupportedFormat[1]" -m 'SupportedFormat[position()>1]' -o ' ' -v . -b -o "$" -v "SupportedCRS[1]" -m 'SupportedCRS[position()>1]' -o ' ' -v . -b -n WCS/"$field1"/wcs_capabilities_temp.xml > layers_list_temp.csv
			   			    
			    [ -e WCS/"$field1"/service_layers_"$url"_"$version".csv ] && rm WCS/"$field1"/service_layers_"$url"_"$version".csv

                echo "Layers:"
			    
			    INPUT=layers_list_temp.csv
			    OLDIFS=$IFS
			    IFS=$
			    [ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
			    while read l_id l_title l_abstract l_keywords l_wgs84bbox l_bbox l_format l_crs
			    do

                echo $l_title

			    layer_record="$field1""$""$field2""$""$field3""$""$gdal_url""$""$version_dot""$""$SERVICE_TITLE""$""$SERVICE_ABSTRACT""$""$l_id""$""$l_title""$""$l_abstract""$""$l_keywords""$""$l_wgs84bbox""$""$l_bbox""$""$l_format""$""$l_crs"
			    echo "$layer_record" >> WCS/"$field1"/service_layers_"$url"_"$version".csv
			    echo "$layer_record" >> snig_geonetwork_records_wcs_layers.csv
		    
			    done < $INPUT
			    IFS=$OLDIFS

                rm WCS/"$field1"/wcs_capabilities_temp.xml
                rm layers_list_temp.csv

		    else
			    success="false"
			    SERVICE_TITLE="N/A"
			    SERVICE_ABSTRACT="N/A"
                SERVICE_ABSTRACT="N/A"
			    SERVICE_TYPE="N/A"
			    SERVICE_CONSTRAINTS="N/A"
			    SERVICE_VERSIONS="N/A"
			    SERVICE_KEYWORDS="N/A"
			    SERVICE_PERSON="N/A"
			    SERVICE_PROVIDER="N/A"
			    SERVICE_ADDRESS="N/A"
			    SERVICE_CITY="N/A"
			    SERVICE_COUNTRY="N/A"
			    SERVICE_EMAIL="N/A"
                SERVICE_FORMATS="N/A"
                SERVICE_CRS="N/A"
		    fi

        		record="$field1""$""$field2""$""$field3""$""$gdal_url""$""$SERVICE_TITLE""$""$SERVICE_ABSTRACT""$""$SERVICE_TYPE""$""$SERVICE_KEYWORDS""$""$SERVICE_VERSIONS""$""$SERVICE_CONSTRAINTS""$""$SERVICE_PERSON""$""$SERVICE_PROVIDER""$""$SERVICE_ADDRESS""$""$SERVICE_CITY""$""$SERVICE_COUNTRY""$""$SERVICE_EMAIL""$""$SERVICE_FORMATS""$""$SERVICE_CRS""$""$gdalinfo_code_no_color""$""$success"
        		echo "$record" >> snig_geonetwork_records_wcs_gdalinfo_status_codes.csv

        done

    fi

                printf "\n"
                printf "\n"
                printf "\n"


done < $INPUT
IFS=$OLDIFS
