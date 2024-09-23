#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
NC='\033[0m'

export CPL_CURL_IGNORE_ERROR=YES

[ -e snig_geonetwork_records_wfs_ogrinfo_status_codes.csv ] && rm snig_geonetwork_records_wfs_ogrinfo_status_codes.csv
[ -e snig_geonetwork_records_wfs_layers.csv ] && rm snig_geonetwork_records_wfs_layers.csv

INPUT=snig_geonetwork_records_wfs_urls_check_capabilities.csv
OLDIFS=$IFS
IFS=$
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
while read field1 field2 field3 field4 field5 field6 field7
do

    if [ "$field6" = "ok" ]; then

        url=$(echo "$field4" | cut -f1 -d"?" | sed -r 's/http:\/\///g' |  sed -r 's/https:\/\///g' |  sed -r 's/\//_/g' | sed -r 's/\./_/g')


        if [[ "${field4,,}" == *version=2.0.0* ]]; then
            declare -a version_underscore=("2_0_0" "1_1_0" "1_0_0")
        elif [[ "${field4,,}" == *version=1.1.0* ]]; then
            declare -a version_underscore=("1_1_0" "1_0_0")
        elif [[ "${field4,,}" == *version=1.0.0* ]]; then
            declare -a version_underscore=("1_0_0")
        else
            declare -a version_underscore=("1_0_0")
        fi


        echo -e "${YELLOW}Downloading OGR WFS infos for record $field1 / $field2 / $field3${NC}"
        echo -e "Original URL: ${YELLOW}$field7${NC}"


        for version in "${version_underscore[@]}"
        do


            if [[ "$version" = 2_0_0 ]]; then
                version_dot=2.0.0
            elif [[ "$version" = 1_1_0 ]]; then
                version_dot=1.1.0
            else
                version_dot=1.0.0
            fi
            

			echo -e "${GREEN}Downloading OGR response in standard format for version $version_dot${NC}"


            if [[ "$version" = 2_0_0 ]]; then
                ogr_url=$field4
            elif [[ "$version" = 1_1_0 ]]; then
                ogr_url=$(echo "$field4" | sed -r 's/2.0.0/1.1.0/g')
            else
                ogr_url=$(echo "$field4" | sed -r 's/2.0.0/1.0.0/g' | sed -r 's/1.1.0/1.0.0/g')
            fi

            echo -e "Request URL: ${YELLOW}$ogr_url${NC}"

#########
						if [ ! -d "WFS_TEMP/$url" ]; then
						    mkdir WFS_TEMP/"$url"
                            ogrinfo -so "WFS:${ogr_url}" > WFS_TEMP/"$url"/info_"$url"_"$version".txt 2>&1
                            cp WFS_TEMP/"$url"/info_"$url"_"$version".txt WFS/"$field1"/
                        elif [ -d "WFS_TEMP/$url" ] && [ ! -f "WFS_TEMP/"$url"/info_"$url"_"$version".txt" ]; then
                            ogrinfo -so "WFS:${ogr_url}" > WFS_TEMP/"$url"/info_"$url"_"$version".txt 2>&1
                            cp WFS_TEMP/"$url"/info_"$url"_"$version".txt WFS/"$field1"/
                        else
                            cp WFS_TEMP/"$url"/info_"$url"_"$version".txt WFS/"$field1"/
						fi
#########

            #ogrinfo -so "WFS:${ogr_url}" > WFS/"$field1"/info_"$url"_"$version".txt 2>&1

            info_start=$(sed -n '1{/^INFO:/p};q' WFS/"$field1"/info_"$url"_"$version".txt)

		    if grep -R -q "using driver \`WFS' successful" WFS/"$field1"/info_"$url"_"$version".txt
		    then
			        if [ -z "$info_start" ] || [[ $(<WFS/"$field1"/info_"$url"_"$version".txt) == *ServiceExceptionReport* ]] || [[ $(<WFS/"$field1"/info_"$url"_"$version".txt) == *ERROR* ]];
			        then
				        ogrinfo_code="${ORANGE}ok (errors or warnings)${NC}"    
			        else
				        ogrinfo_code="${GREEN}ok${NC}"
                    fi
            else
                        ogrinfo_code="${RED}error${NC}"
		    fi


		    echo -e "$ogrinfo_code"
		    ogrinfo_code_no_color=$(echo "$ogrinfo_code" | sed -r 's/\033\[0;32m//g' |  sed -r 's/\033\[0m//g' |  sed -r 's/\033\[0;31m//g' | sed -r 's/\033\[0;33m//g' | sed -r 's/\033\[1;33m//g'  | sed -r 's/\\//g')

		    if [[ "$ogrinfo_code_no_color" == *"ok"* ]]; then

			    success="true"
			    
			    echo -e "${GREEN}Downloading OGR response in JSON format for version $version_dot${NC}"
                echo -e "Request URL: ${YELLOW}$ogr_url${NC}"

#########
						if [ -f "WFS_TEMP/"$url"/info_"$url"_"$version".json" ]; then
                            cp WFS_TEMP/"$url"/info_"$url"_"$version".json WFS/"$field1"/
                        else
                            ogrinfo -json -noextent -so "WFS:${ogr_url}" > WFS_TEMP/"$url"/info_"$url"_"$version".json 2> /dev/null
                            cp WFS_TEMP/"$url"/info_"$url"_"$version".json WFS/"$field1"/
						fi
#########
	    
			    jq -r '.metadata."".TITLE,"$",.metadata."".ABSTRACT,"$",.metadata."".PROVIDER_NAME' WFS/"$field1"/info_"$url"_"$version".json | tr -d "\n\r" > WFS/"$field1"/service_title_abstract_"$url"_"$version".csv
			    
			    SERVICE_TITLE=$(jq -r '.metadata."".TITLE' WFS/"$field1"/info_"$url"_"$version".json)
			    SERVICE_ABSTRACT=$(jq -r '.metadata."".ABSTRACT' WFS/"$field1"/info_"$url"_"$version".json | tr -d "\n\r")
                SERVICE_ABSTRACT="$(echo "$SERVICE_ABSTRACT" | sed 's/\r//' | sed ':a;N;$!ba;s/\n/ /g')"
			    SERVICE_PROVIDER=$(jq -r '.metadata."".PROVIDER_NAME' WFS/"$field1"/info_"$url"_"$version".json)

                ### TO DO: EXTRACT KEYWORDS

                echo "Title:" $SERVICE_TITLE
                echo "Abstract:" $SERVICE_ABSTRACT
                echo "Provider:" $SERVICE_PROVIDER
	    
			    jq -r '.layers | map(.name),map(.metadata."".TITLE),map(.geometryFields[].type),map(.featureCount|@sh),map(.geometryFields[].coordinateSystem.projjson.id.authority|@sh),map(.geometryFields[].coordinateSystem.projjson.id.code|@sh) | @csv' WFS/"$field1"/info_"$url"_"$version".json | sed s/\",\"/\"$\"/g | csvtool -t $ -u $ transpose - > layers_list_temp.csv			
			   			    
			    [ -e WFS/"$field1"/service_layers_"$url"_"$version".csv ] && rm WFS/"$field1"/service_layers_"$url"_"$version".csv

                echo "Layers:"
			    
			    INPUT=layers_list_temp.csv
			    OLDIFS=$IFS
			    IFS=$
			    [ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
			    while read l_name l_title l_type l_feature_count l_authority l_crs
			    do

                echo $l_title

			    layer_record="$field1""$""$field2""$""$field3""$""$ogr_url""$""$version_dot""$""$SERVICE_TITLE""$""$SERVICE_ABSTRACT""$""$SERVICE_PROVIDER""$""$l_name""$""$l_title""$""$l_type""$""$l_feature_count""$""$l_authority""$""$l_crs"
			    echo "$layer_record" >> WFS/"$field1"/service_layers_"$url"_"$version".csv
			    echo "$layer_record" >> snig_geonetwork_records_wfs_layers.csv
		    
			    done < $INPUT
			    IFS=$OLDIFS

                printf "\n"
                printf "\n"
                printf "\n"

		    else
			    success="false"
			    SERVICE_ABSTRACT="N/A"
			    SERVICE_TITLE="N/A"
                SERVICE_PROVIDER="N/A"
		    fi

        		record="$field1""$""$field2""$""$field3""$""$ogr_url""$""$version_dot""$""$SERVICE_TITLE""$""$SERVICE_ABSTRACT""$""$SERVICE_PROVIDER""$""$ogrinfo_code_no_color""$""$success"
        		echo "$record" >> snig_geonetwork_records_wfs_ogrinfo_status_codes.csv

        done

    fi


done < $INPUT
IFS=$OLDIFS

rm layers_list_temp.csv
