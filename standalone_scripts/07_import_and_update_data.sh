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

# Use the records in \"uris_long_temp\" to delete from \"uris_long\" the recorsds with UUIDs/uris that do not exist anymore or
# uris that have changed, then import in \"uris_long\" from \"uris_long_temp\" the records corresponding to UUIDs/uris that are missing

-- NOTE: removed records from testsuite.uris_long, log and status tables will
-- be kept in history tables, that will be populated with TRIGGERS, not with queries
-- as initially done.
-- The queries here below can be optimized (ON CASCADE...) but for sake of clarity now
-- are written in a more basic way



-- Find records in testsuite.uris_long and status and log tables that have UUIDs that are not existing anymore
-- among the ones that are in the testsuite.uris_long_temp, which is the result of a new catalog harvest,
-- and delete them

CREATE TEMP TABLE temp_table AS 
SELECT DISTINCT uuid FROM testsuite.uris_long a 
WHERE a.uuid NOT IN (SELECT DISTINCT b.uuid FROM testsuite.uris_long_temp b);

DELETE FROM testsuite.uris_long 
WHERE uuid IN (SELECT uuid FROM temp_table);

DELETE FROM testsuite.service_log 
WHERE uuid IN (SELECT uuid FROM temp_table);

DELETE FROM testsuite.service_status 
WHERE uuid IN (SELECT uuid FROM temp_table);

DROP TABLE temp_table;



-- Do the same for URLs

CREATE TEMP TABLE temp_table AS 
SELECT DISTINCT uri_original FROM testsuite.uris_long a 
WHERE a.uri_original NOT IN (SELECT DISTINCT b.uri_original FROM testsuite.uris_long_temp b);

DELETE FROM testsuite.uris_long 
WHERE uri_original IN (SELECT uri_original FROM temp_table);

DROP TABLE temp_table;



-- Now possibly a number of records with some specific gid have been removed from testsuite.uris_long
-- so we remove the entries with the same gid from the status and log tables

DELETE FROM testsuite.service_log a
WHERE a.gid NOT IN (SELECT DISTINCT b.gid FROM testsuite.uris_long b);

DELETE FROM testsuite.service_status a 
WHERE a.gid NOT IN (SELECT DISTINCT b.gid FROM testsuite.uris_long b);



-- Add in testsuite.uris_long all the new records (by uuid and uri_original) that are now
-- in testsuite.uris_long_temp because of the new harvest

INSERT INTO testsuite.uris_long ( 
    uuid, 
    entity, 
    description, 
    uri, 
    uri_type, 
    eid, 
    version, 
    uri_original 
) 
SELECT 
    uuid, 
    entity, 
    description, 
    uri, 
    uri_type, 
    eid, 
    version, 
    uri_original 
FROM (SELECT * FROM testsuite.uris_long_temp a 
WHERE a.uuid NOT IN (SELECT DISTINCT b.uuid FROM testsuite.uris_long b));

INSERT INTO testsuite.uris_long ( 
    uuid, 
    entity, 
    description, 
    uri, 
    uri_type, 
    eid, 
    version, 
    uri_original 
) 
SELECT 
    uuid, 
    entity, 
    description, 
    uri, 
    uri_type, 
    eid, 
    version, 
    uri_original 
FROM (SELECT * FROM testsuite.uris_long_temp a 
WHERE a.uri_original NOT IN (SELECT DISTINCT b.uri_original FROM testsuite.uris_long b));



-- Update the entities table, with new entities that may have appeared
-- after a new harvest

INSERT INTO testsuite.entities (description) 
SELECT DISTINCT entity FROM testsuite.uris_long_temp
WHERE entity IS NOT NULL AND entity NOT IN (SELECT description FROM testsuite.entities 
WHERE description IS NOT NULL);


-- Update the testsuite.uris_long table so to fill the empty eid values
-- in case of reocrds belonging to a new entity
UPDATE testsuite.uris_long a 
SET eid = b.eid 
FROM testsuite.entities b 
WHERE a.eid IS NULL 
AND a.entity = b.description;

UPDATE testsuite.uris_long a 
SET eid = b.eid 
FROM testsuite.entities b 
WHERE a.eid IS NULL 
AND b.description IS NULL;


-- While in testsuite.uris_long_temp we NEED / WANT to keep reords with the same uri_original,
-- becase we NEED to compute stats about the levels of redundancy in the catalog,
-- in testsuite.uris_long we DON\'T want to have repeated uri, because we DON'\T to test
-- over and over the same uri even if it belongs to a different UUID. We DON\'T care if a specific
-- uri is tested for a specific UUID or another. The entity for a specific uri remain the same,
-- and while the decription of the UUID may change, we also DON'T care. If a specific uri works or does not
-- the results apply to all UUIDs of the catalog where it was added. So if it does not work, once fixed,
-- all are fixed.

ADD HERE QUERY TO REMOVE DUPLICATES FROM testsuite.uris_long BY USING uri values
