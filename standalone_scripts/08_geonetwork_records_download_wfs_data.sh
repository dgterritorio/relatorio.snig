#!/bin/bash

# Warning: downloaing data from WFS services can occuoy a lot of disk space

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
NC='\033[0m'

export CPL_CURL_IGNORE_ERROR=YES

[ -e snig_geonetwork_records_wfs_layers_download.csv ] && rm snig_geonetwork_records_wfs_layers_download.csv

INPUT=snig_geonetwork_records_wfs_ogrinfo_status_codes.csv
OLDIFS=$IFS
IFS=$
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
while read field1 field2 field3 field4 field5 field6 field7 field8 field9 field10
do

if [[ "$field10" = true ]]; then

        echo -e "${YELLOW}Downloading WFS data for record $field1 / $field2 / $field3${NC}"

            echo "Title: $field6"
            printf "\n"
            echo "Abstract: $field7"
            printf "\n"
            echo "Provider: $field8"
            printf "\n"
            echo "Original URL: $field4"
            printf "\n"

        url=$(echo "$field4" | cut -f1 -d"?" | sed -r 's/http:\/\///g' |  sed -r 's/https:\/\///g' |  sed -r 's/\//_/g' | sed -r 's/\./_/g' | sed -r 's/-/_/g')

            if [[ "$field5" = 2.0.0 ]] && [[ "$field4" != *servicos.dgterritorio.pt* ]] && [[ "$field4" != *www.ifap.pt* ]]; then
                declare -a version_underscore=("2_0_0" "1_1_0" "1_0_0")
            elif [[ "$field5" = 2.0.0 ]] && ([[ "$field4" == *servicos.dgterritorio.pt* ]] || [[ "$field4" == *www.ifap.pt* ]]); then
                declare -a version_underscore=("1_1_0" "1_0_0")
            elif [[ "$field5" = 1.1.0 ]]; then
                declare -a version_underscore=("1_1_0" "1_0_0")
            elif [[ "$field5" = 1.0.0 ]]; then
                declare -a version_underscore=("1_0_0")
            else
                declare -a version_underscore=("1_0_0")
            fi


for version in "${version_underscore[@]}"
do


            if [[ "$version" = 2_0_0 ]]; then
                version_dot=2.0.0
            elif [[ "$version" = 1_1_0 ]]; then
                version_dot=1.1.0
            else
                version_dot=1.0.0
            fi


	        echo "Downloading WFS data for WFS $version_dot version"	


            if [[ "$version" = 2_0_0 ]]; then
                ogr_url=$field4
            elif [[ "$version" = 1_1_0 ]]; then
                ogr_url=$(echo "$field4" | sed -r 's/2.0.0/1.1.0/g')
            else
                ogr_url=$(echo "$field4" | sed -r 's/2.0.0/1.0.0/g' | sed -r 's/1.1.0/1.0.0/g')
            fi


            if [ -f WFS/"$field1"/ogr2ogr_"$url"_"$version".gpkg ] || [ -f WFS/"$field1"/ogr2ogr_"$url"_"$version"_skipfailures.gpkg ]; then
         
                    echo -e "${ORANGE}Dataset already downloaded for this version, skipping${NC}"

                        if grep -q "Terminating translation prematurely after failed" WFS/"$field1"/ogr2ogr_"$url"_"$version"_errors.txt || grep -q "Terminating translation prematurely after failed" WFS/"$field1"/ogr2ogr_"$url"_"$version".txt; then
                          echo -e "${RED}OGR2OGR translation failed, trying again with the \"skipfailures\" option${NC}"
                          mv WFS/"$field1"/ogr2ogr_"$url"_$version.txt WFS/"$field1"/ogr2ogr_"$url"_"$version"_errors.txt
                          mv WFS/"$field1"/ogr2ogr_"$url"_$version.gpkg WFS/"$field1"/ogr2ogr_"$url"_"$version"_errors.gpkg
                          echo -e "${ORANGE}Downloading again WFS data for WFS $version_dot version, skipping failures${NC}"

						            if [ ! -f WFS/"$field1"/ogr2ogr_"$url"_"$version"_skipfailures.gpkg ]; then
                                        ogr2ogr -f GPKG WFS/"$field1"/ogr2ogr_"$url"_"$version"_skipfailures.gpkg "WFS:${ogr_url}" -overwrite -skipfailures > WFS/"$field1"/ogr2ogr_"$url"_"$version"_skipfailures.txt 2>&1
                                    fi

                          status="skipfailures"
                          before_skip=$(<WFS/"$field1"/ogr2ogr_"$url"_"$version"_errors.txt)
                          after_skip=$(<WFS/"$field1"/ogr2ogr_"$url"_"$version"_skipfailures.txt)
                          before_skip="$(echo "$before_skip" | sed 's/\r//' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/<[^>]*>//g')"
                          after_skip="$(echo "$after_skip" | sed 's/\r//' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/<[^>]*>//g')"
                          file_name=ogr2ogr_"$url"_"$version"_skipfailures.gpkg
                        else
                          status="ok"
                          before_skip=""
                          after_skip=""
                          file_name=ogr2ogr_"$url"_"$version".gpkg
                        fi

            else

	        echo -e "Request URL: ${ORANGE}$ogr_url${NC}"
		        
            #########
						if [ ! -d "WFS_TEMP/$url" ]; then
						    mkdir WFS_TEMP/"$url"
                            ogr2ogr -f GPKG WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version".gpkg "WFS:${ogr_url}" -overwrite > WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version".txt 2>&1
                            rsync -av --progress WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version".* WFS/"$field1"/
                        elif [ -d "WFS_TEMP/$url" ] && [ ! -f "WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version".gpkg" ]; then
                            ogr2ogr -f GPKG WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version".gpkg "WFS:${ogr_url}" -overwrite > WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version".txt 2>&1
                            rsync -av --progress WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version".* WFS/"$field1"/
                        else
                            rsync -av --progress WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version".* WFS/"$field1"/
						fi
            #########

	                    #ogr2ogr -f GPKG WFS/"$field1"/ogr2ogr_"$url"_"$version".gpkg "WFS:${ogr_url}" -overwrite > WFS/"$field1"/ogr2ogr_"$url"_"$version".txt 2>&1

                        if grep -q "Terminating translation prematurely after failed" WFS/"$field1"/ogr2ogr_"$url"_"$version".txt; then
                          echo -e "${RED}OGR2OGR translation failed, trying again with the \"skipfailures\" option${NC}"
                          mv WFS/"$field1"/ogr2ogr_"$url"_$version.txt WFS/"$field1"/ogr2ogr_"$url"_"$version"_errors.txt
                          mv WFS/"$field1"/ogr2ogr_"$url"_$version.gpkg WFS/"$field1"/ogr2ogr_"$url"_"$version"_errors.gpkg
                          echo -e "${ORANGE}Downloading again WFS data for WFS $version_dot version, skipping failures${NC}"

            #########
						            if [ ! -f "WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version"_skipfailures.gpkg" ]; then
                                        ogr2ogr -f GPKG WFS/"$field1"/ogr2ogr_"$url"_"$version"_skipfailures.gpkg "WFS:${ogr_url}" -overwrite -skipfailures > WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version"_skipfailures.txt 2>&1
                                        rsync -av --progress WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version"_skipfailures.* WFS/"$field1"/
                                    else
                                        rsync -av --progress WFS_TEMP/"$url"/ogr2ogr_"$url"_"$version"_skipfailures.* WFS/"$field1"/
						            fi
            #########

                          status="skipfailures"
                          before_skip=$(<WFS/"$field1"/ogr2ogr_"$url"_"$version"_errors.txt)
                          after_skip=$(<WFS/"$field1"/ogr2ogr_"$url"_"$version"_skipfailures.txt)
                          before_skip="$(echo "$before_skip" | sed 's/\r//' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/<[^>]*>//g')"
                          after_skip="$(echo "$after_skip" | sed 's/\r//' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/<[^>]*>//g')"
                          file_name=ogr2ogr_"$url"_"$version"_skipfailures.gpkg
                        else
                          status="ok"
                          before_skip=""
                          after_skip=""
                          file_name=ogr2ogr_"$url"_"$version".gpkg
                        fi
    fi

	          record="$field1""$""$field2""$""$field3""$""$field4""$""$ogr_url""$""$version_dot""$""$status""$""$before_skip""$""$after_skip""$""$file_name"
        		echo "$record" >> snig_geonetwork_records_wfs_layers_download.csv

done

        printf "\n"
        printf "\n"
        printf "\n"

fi

done < $INPUT
IFS=$OLDIFS
