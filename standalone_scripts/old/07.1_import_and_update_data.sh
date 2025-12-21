#!/bin/bash

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Import common PostgreSQL connection parameters
source "$SCRIPT_DIR/connection_parameters.txt"

# Import the \"long\" and \"wide\" CSVs to PostgreSQL
psql -U $USERNAME -d $DB_NAME -h $HOST -c "TRUNCATE TABLE testsuite.uris_wide;"
psql -U $USERNAME -d $DB_NAME -h $HOST -c "ALTER SEQUENCE testsuite.uris_wide_gid_seq RESTART WITH 1;"
psql -U $USERNAME -d $DB_NAME -h $HOST -c "\COPY testsuite.uris_wide(uuid,entity,description,uri1,uri2,uri3,uri4,uri5,uri6,uri7,uri8,uri9,uri10,uri11,uri12,uri13) FROM $BASEFOLDER/geonetwork_records_urls_wide.csv DELIMITER '$' CSV;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "TRUNCATE TABLE testsuite.uris_long_temp;"
psql -U $USERNAME -d $DB_NAME -h $HOST -c "ALTER SEQUENCE testsuite.uris_long_temp_gid_seq RESTART WITH 1;"
psql -U $USERNAME -d $DB_NAME -h $HOST -c "\COPY testsuite.uris_long_temp(uuid,entity,description,uri_original,uri_type,version,uri) FROM $BASEFOLDER/geonetwork_records_urls_long_with_type.csv DELIMITER '$' CSV;"

# In the \"long\" temp table copy to the proper column, for records that are not OGC services, the URLs to be tested
psql -U $USERNAME -d $DB_NAME -h $HOST -c "UPDATE testsuite.uris_long_temp SET uri=uri_original WHERE uri IS NULL;"

# another approach that exploits the ON DELETE CASCADE features the automatic removal of 
# records in a table (service_status, service_log) based on the deletion of rows in another
# table whose primary key (gid) is a foreign key in service_status and service_log 

# ***** To be run only once! *****

# I guess gid was to be defined beforehand as foreign key for both service_status and service_log. Currently it's not!

ALTER TABLE testsuite.service_status ADD CONSTRAINT "service_gid_ref1" FOREIGN KEY (gid) REFERENCES uris_long (gid) ON DELETE CASCADE;
ALTER TABLE testsuite.service_log    ADD CONSTRAINT "service_gid_ref2" FOREIGN KEY (gid) REFERENCES uris_long (gid) ON DELETE CASCADE;

# 
#
#   +-----------------------------------+ uris_long
#   |                                   |
#   |                                   |
#   |                                   |
#   |                                   |
#   |         A         +------------------------------------+
#   |                   |               |                    |
#   |                   |               |                    |
#   |                   |       B       |                    |
#   |                   |               |                    |
#   |                   |               |                    |
#   +-------------------|---------------+          C         |
#                       |                                    |
#                       |                                    |
#                       |                                    |
#                       |                                    |
#      uris_long_temp   +------------------------------------+
#
#
# A: Rows in uris_long but not in uris_long_temp
# B: Rows in both uris_long and uris_long_temp
# C: Rows in uris_long_temp but not in uris_long
#
# How can determine if a row belongs to uris_long or to uris_long table? 
# * It's the uri column * as per telephone conversation we had last sunday

# I'm assuming that column uri uniquely identifies a row (some sort
# of constraint should enforce this fact)

# Remove records of set A
# 
# If the constraints I defined above are applied then records in service_status
# and service_log are removed automatically

DELETE FROM testsuite.uris_long WHERE uri NOT IN (SELECT uri from testsuite.uris_long_temp);

# Update records of set B

WITH subquery AS (
    SELECT uuid,entity,description,eid,uri_original
    FROM  testsuite.uris_long_temp
)
UPDATE testsuite.uris_long
SET uuid        = subquery.uuid,
    entity      = subquery.entity,
    eid         = subquery.eid,
    description = subquery.description,
    uri_original = subquery.uri_original
FROM subquery
WHERE testsuite.uris_long.uri = subquery.uri;

# insert records of set C

INSERT INTO testsuite.uris_long ul (uri,uri_original,uri_type,version,entity,description,eid) VALUES 
    (SELECT uri,uri_original,uri_type,version,entity,description,eid from testsuite.uris_long_temp ult where ult.uri NOT IN
    (SELECT uri FROM testsuite.uris_long))
