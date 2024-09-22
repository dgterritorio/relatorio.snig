#!/bin/bash

[ -e snig_geonetwork_records_urls_status_codes.csv ] && rm snig_geonetwork_records_urls_status_codes.csv

INPUT=snig_geonetwork_records_csv_urls.csv
OLDIFS=$IFS
IFS=$
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
while read field1 field7 field52 field169 field175 field181 field187 field193 field199 field205 field211 field217 field223 field229 field235 field241
do

echo "Checking URLs for record $field1 / $field7 / $field52"

        for value in field169 field175 field181 field187 field193 field199 field205 field211 field217 field223 field229 field235 field241
                do
                url=$value

                        if [ -z ${!url} ]; then
                                echo "Empty URL field, skipping"
                        else
                                echo "Checking status code for" ${!url}
 
                                status_code_and_time=$( TIMEFORMAT="%R"; { time curl -X GET -m 25 -o /dev/null -Isw '%{http_code}\n' "${!url}"; } 2>&1 )
                                status_code_and_time_single_line=$(echo "$status_code_and_time" | tr '\n' ' ')
                                sc=$(echo $status_code_and_time_single_line | cut -d " " -f 1)
                                time=$(echo $status_code_and_time_single_line | cut -d " " -f 2)
                                time_dot=$(echo $time | sed 's/,/./')
                                echo $sc
                                echo $time_dot
                                record="$field1""$""$field7""$""$field52""$""${!url}""$""$sc""$""$time_dot"

                                echo "$record" >> snig_geonetwork_records_urls_status_codes.csv
                        fi

        done

done < $INPUT
IFS=$OLDIFS
