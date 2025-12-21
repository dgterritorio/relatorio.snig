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

# In the \"long\" temp table copy to the proper column the URLs to be tested (for records that are not OGC services)
psql -U $USERNAME -d $DB_NAME -h $HOST -c "UPDATE testsuite.uris_long_temp SET uri=uri_original WHERE uri IS NULL;"

# Find records in testsuite.uris_long and status and log tables that have UUIDs that are not existing anymore
# among the ones that are in the testsuite.uris_long_temp, which is the result of a new catalog harvest,
# and delete them
psql -U $USERNAME -d $DB_NAME -h $HOST -c "CREATE TABLE temp_table AS \
SELECT DISTINCT uuid FROM testsuite.uris_long a \
WHERE a.uuid NOT IN (SELECT DISTINCT b.uuid FROM testsuite.uris_long_temp b);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "DELETE FROM testsuite.uris_long \
WHERE uuid IN (SELECT uuid FROM temp_table);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "DELETE FROM testsuite.service_log \
WHERE uuid IN (SELECT uuid FROM temp_table);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "DELETE FROM testsuite.service_status \
WHERE uuid IN (SELECT uuid FROM temp_table);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "DROP TABLE temp_table;"


# Do the same for URLs
psql -U $USERNAME -d $DB_NAME -h $HOST -c "CREATE TABLE temp_table AS \
SELECT DISTINCT uri_original FROM testsuite.uris_long a \
WHERE a.uri_original NOT IN (SELECT DISTINCT b.uri_original FROM testsuite.uris_long_temp b);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "DELETE FROM testsuite.uris_long \
WHERE uri_original IN (SELECT uri_original FROM temp_table);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "DROP TABLE temp_table;"


# (Possibly) records with some specific gid have been removed from testsuite.uris_long
# so we remove the entries with the same gid from the status and log tables
psql -U $USERNAME -d $DB_NAME -h $HOST -c "DELETE FROM testsuite.service_log a \
WHERE a.gid NOT IN (SELECT DISTINCT b.gid FROM testsuite.uris_long b);"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "DELETE FROM testsuite.service_status a \
WHERE a.gid NOT IN (SELECT DISTINCT b.gid FROM testsuite.uris_long b);"


# Add in testsuite.uris_long all the new records (by uuid and uri_original) that are
# in testsuite.uris_long_temp because of the new harvest
psql -U $USERNAME -d $DB_NAME -h $HOST -c "INSERT INTO testsuite.uris_long ( \
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

psql -U $USERNAME -d $DB_NAME -h $HOST -c "INSERT INTO testsuite.uris_long ( \
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
WHERE a.uri_original NOT IN (SELECT DISTINCT b.uri_original FROM testsuite.uris_long b));"


# Update the entities table, with new entities that may have appeared after a new harvest
psql -U $USERNAME -d $DB_NAME -h $HOST -c "INSERT INTO testsuite.entities (description) \
SELECT DISTINCT entity FROM testsuite.uris_long_temp \
WHERE entity IS NOT NULL AND entity NOT IN (SELECT description FROM testsuite.entities \
WHERE description IS NOT NULL);"


# Update the testsuite.uris_long table so to fill the empty eid values for the records belonging to a new entity
psql -U $USERNAME -d $DB_NAME -h $HOST -c "UPDATE testsuite.uris_long a \
SET eid = b.eid \
FROM testsuite.entities b \
WHERE a.eid IS NULL \
AND a.entity = b.description;"

psql -U $USERNAME -d $DB_NAME -h $HOST -c "UPDATE testsuite.uris_long a \
SET eid = b.eid \
FROM testsuite.entities b \
WHERE a.eid IS NULL \
AND b.description IS NULL;"


# In testsuite.uris_long_temp we NEED / WANT to keep records with the same uri_original,
# because we NEED to compute stats about the levels of redundancy in the catalog,
# in testsuite.uris_long we DON\'T want to have repeated uri, because we DON'\T want to test
# over and over the same uri even if it belongs to different UUIDs. We DON\'T care if a specific
# uri is tested for a specific UUID or another. The entity responsible for a specific uri remain the same,
# and while the decription of the UUID may change, we also DON'T care. If a specific uri works or does not
# the results apply to all UUIDs of the catalog where it was added. So if it does not work, once is fixed,
# all are fixed.

psql -U $USERNAME -d $DB_NAME -h $HOST -c "WITH duplicates AS ( \
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY uri ORDER BY ctid) AS rn \
    FROM testsuite.uris_long \
) \
DELETE FROM testsuite.uris_long \
WHERE ctid IN ( \
    SELECT ctid \
    FROM duplicates \
    WHERE rn > 1 \
    );"
