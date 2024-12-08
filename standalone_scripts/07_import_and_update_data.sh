#!/bin/bash

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Import common PostgreSQL connection parameters
source "$SCRIPT_DIR/connection_parameters.txt"

# Import the \"long\" and \"wide\" CSVs to PostgreSQL
psql -U $USERNAME -d $DB_NAME -h $HOST -c "TRUNCATE TABLE testsuite.uris_wide;"
psql -U $USERNAME -d $DB_NAME -h $HOST -c "ALTER SEQUENCE testsuite.uris_wide_gid_seq RESTART WITH 1;"
psql -U $USERNAME -d $DB_NAME -h $HOST -c "\COPY testsuite.uris_wide(uuid,entity,description,uri1,uri2,uri3,uri4,uri5,uri6,uri7,uri8,uri9,uri10,uri11,uri12,uri13) FROM $BASEFOLDER/geonetwork_records_urls_wide.csv DELIMITER '$' CSV;"
psql -U $USERNAME -d $DB_NAME -h $HOST -c "\COPY testsuite.uris_wide_all(uuid,entity,description,uri1,uri2,uri3,uri4,uri5,uri6,uri7,uri8,uri9,uri10,uri11,uri12,uri13) FROM $BASEFOLDER/geonetwork_records_urls_wide.csv DELIMITER '$' CSV;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "TRUNCATE TABLE testsuite.uris_long_temp;"
psql -U $USERNAME -d $DB_NAME -h $HOST -c "ALTER SEQUENCE testsuite.uris_long_temp_gid_seq RESTART WITH 1;"
psql -U $USERNAME -d $DB_NAME -h $HOST -c "\COPY testsuite.uris_long_temp(uuid,entity,description,uri_original,uri_type,version,uri) FROM $BASEFOLDER/geonetwork_records_urls_long_with_type.csv DELIMITER '$' CSV;"

# In the \"long\" temp table copy to the proper column, for records that are not OGC services, the URLs to be tested
psql -U $USERNAME -d $DB_NAME -h $HOST -c "UPDATE testsuite.uris_long_temp SET uri=uri_original WHERE uri IS NULL;"

# Use the records in \"uris_long_temp\" to delete from \"uris_long\" the recorsds with UUIDs that do not exist anymore and
# URLs that have changed, then import in \"uris_long\" from \"uris_long_temp\" the records corresponding to UUIDs that are missing
# Also make copies of deleted records in the approrriate \"_deleted\" tables
psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"CREATE TEMP TABLE temp_table AS \
SELECT DISTINCT uuid FROM testsuite.uris_long a \
WHERE a.uuid NOT IN (SELECT DISTINCT b.uuid FROM testsuite.uris_long_temp b);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"WITH temp1 AS ( \
SELECT * FROM testsuite.uris_long \
WHERE uuid IN (SELECT uuid FROM temp_table) \
) \
INSERT INTO testsuite.uris_long_deleted ( \
    uuid, \
    entity, \
    description, \
    uri, \
    uri_type, \
    eid, \
    version, \
    uri_original \
) \
SELECT \
    uuid, \
    entity, \
    description, \
    uri, \
    uri_type, \
    eid, \
    version, \
    uri_original \
FROM temp1;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"DELETE FROM testsuite.uris_long \
WHERE uuid IN (SELECT uuid FROM temp_table);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"DROP TABLE temp_table;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"CREATE TEMP TABLE temp_table AS \
SELECT DISTINCT uuid FROM testsuite.service_log a \
WHERE a.uuid NOT IN (SELECT DISTINCT b.uuid FROM testsuite.uris_long_temp b);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"WITH temp2 AS ( \
SELECT * FROM testsuite.service_log \
WHERE uuid IN (SELECT uuid FROM temp_table) \
) \
INSERT INTO testsuite.service_log_deleted ( \
    entryid, \
    gid, \
    ts, \
    task, \
    exit_status, \
    exit_info, \
    uuid \
) \
SELECT \
    entryid, \
    gid, \
    ts, \
    task, \
    exit_status, \
    exit_info, \
    uuid \
FROM temp2;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"DELETE FROM testsuite.service_log \
WHERE uuid IN (SELECT uuid FROM temp_table);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"DELETE FROM testsuite.service_status \
WHERE uuid IN (SELECT uuid FROM temp_table);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"DROP TABLE temp_table;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"CREATE TEMP TABLE temp_table AS \
SELECT uuid, uri_original FROM testsuite.uris_long a \
WHERE a.uri_original NOT IN (SELECT DISTINCT b.uri_original FROM testsuite.uris_long_temp b);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"WITH temp1 AS ( \
SELECT * FROM testsuite.uris_long \
WHERE uuid IN (SELECT uuid FROM temp_table) \
) \
INSERT INTO testsuite.uris_long_deleted ( \
    uuid, \
    entity, \
    description, \
    uri, \
    uri_type, \
    eid, \
    version, \
    uri_original \
) \
SELECT \
    uuid, \
    entity, \
    description, \
    uri, \
    uri_type, \
    eid, \
    version, \
    uri_original \
FROM temp1;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"DELETE FROM testsuite.uris_long \
WHERE uuid IN (SELECT uuid FROM temp_table);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"DROP TABLE temp_table;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"INSERT INTO testsuite.service_log_deleted ( \
    entryid, \
    gid, \
    ts, \
    task, \
    exit_status, \
    exit_info, \
    uuid \
) \
SELECT \
    entryid, \
    gid, \
    ts, \
    task, \
    exit_status, \
    exit_info, \
    uuid \
FROM (SELECT * FROM testsuite.service_log c \
WHERE c.gid NOT IN (SELECT DISTINCT d.gid FROM testsuite.uris_long d));"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"DELETE FROM testsuite.service_log c \
WHERE c.gid NOT IN (SELECT DISTINCT d.gid FROM testsuite.uris_long d);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"DELETE FROM testsuite.service_status c \
WHERE c.gid NOT IN (SELECT DISTINCT d.gid FROM testsuite.uris_long d);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"INSERT INTO testsuite.uris_long ( \
    uuid, \
    entity, \
    description, \
    uri, \
    uri_type, \
    eid, \
    version, \
    uri_original \
) \
SELECT \
    uuid, \
    entity, \
    description, \
    uri, \
    uri_type, \
    eid, \
    version, \
    uri_original \
FROM (SELECT * FROM testsuite.uris_long_temp a \
WHERE a.uuid NOT IN (SELECT DISTINCT b.uuid FROM testsuite.uris_long b));"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"INSERT INTO testsuite.entities (description) \
SELECT DISTINCT entity FROM testsuite.uris_long \
WHERE entity IS NOT NULL AND entity NOT IN (SELECT description FROM testsuite.entities \
WHERE description IS NOT NULL);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"UPDATE testsuite.uris_long a \
SET eid = b.eid \
FROM testsuite.entities b \
WHERE a.eid IS NULL \
AND a.entity = b.description;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c \
"UPDATE testsuite.uris_long a \
SET eid = b.eid \
FROM testsuite.entities b \
WHERE a.eid IS NULL \
AND b.description IS NULL;"
