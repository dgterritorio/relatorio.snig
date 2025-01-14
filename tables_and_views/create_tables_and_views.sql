CREATE SCHEMA testsuite;
CREATE SCHEMA stats;

-- CREATE TABLE TO STORE THE LATESTS status OF THE MONITOR
CREATE TABLE IF NOT EXISTS testsuite.service_status
(
    gid integer NOT NULL,
    ts timestamp without time zone NOT NULL,
    task character varying NOT NULL,
    exit_status character varying NOT NULL,
    exit_info text,
    uuid character varying,
    CONSTRAINT service_status_unique UNIQUE (gid, task)
);

-- CREATE TABLE TO STORE THE log OF THE MONITOR
CREATE TABLE IF NOT EXISTS testsuite.service_log
(
    entryid SERIAL,
    gid integer NOT NULL,
    ts timestamp without time zone NOT NULL,
    task character varying NOT NULL,
    exit_status character varying NOT NULL,
    exit_info text,
    uuid character varying
);

-- CREATE TABLE TO STORE THE DELETE RECORDS FROM THE log OF THE MONITOR
CREATE TABLE IF NOT EXISTS testsuite.service_log_deleted
(
    entryid SERIAL,
    gid integer NOT NULL,
    date_deleted TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ts timestamp without time zone NOT NULL,
    task character varying NOT NULL,
    exit_status character varying NOT NULL,
    exit_info text,
    uuid character varying
);

-- CREATE TABLE TO STORE THE entities LIST
CREATE TABLE IF NOT EXISTS testsuite.entities
(
    eid SERIAL,
    description character varying,
    CONSTRAINT entities_pk PRIMARY KEY (eid)
);

-- CREATE TABLE TO STORE GEONETWORK METADATA IN XML FORMAT
CREATE TABLE IF NOT EXISTS testsuite.xml_metadata (
    id SERIAL PRIMARY KEY,
    filename TEXT NOT NULL,
    content XML,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_empty BOOLEAN NOT NULL,
    deleted BOOLEAN DEFAULT FALSE
);

-- CREATE TABLE TO STORE GEONETWORK RECORDS SERVICES URLS IN WIDE FORMAT
-- THIS WILL CONTAIN ONLY THE RESULTS OF THE LAST HARVEST
CREATE TABLE IF NOT EXISTS testsuite.uris_wide
(
    gid SERIAL,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uuid text,
    entity text,
    description text,
    uri1 text,
    uri2 text,
    uri3 text,
    uri4 text,
    uri5 text,
    uri6 text,
    uri7 text,
    uri8 text,
    uri9 text,
    uri10 text,
    uri11 text,
    uri12 text,
    uri13 text,
    CONSTRAINT uris_wide_pkey PRIMARY KEY (gid)
);

-- CREATE TABLE TO STORE GEONETWORK RECORDS SERVICES URLS IN WIDE FORMAT
-- THIS WILL CONTAIN THE RESULTS OF ALL HARVESTS
CREATE TABLE IF NOT EXISTS testsuite.uris_wide_all
(
    gid SERIAL,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uuid text,
    entity text,
    description text,
    uri1 text,
    uri2 text,
    uri3 text,
    uri4 text,
    uri5 text,
    uri6 text,
    uri7 text,
    uri8 text,
    uri9 text,
    uri10 text,
    uri11 text,
    uri12 text,
    uri13 text,
    CONSTRAINT uris_wide_all_pkey PRIMARY KEY (gid)
);

-- CREATE TABLE TO STORE GEONETWORK RECORDS SERVICES URLS IN LONG FORMAT
-- THIS WILL CONTAIN THE INCREMENTAL, NOT REPEATED, LIST OF HARVESTED URLS
-- IF AN URL THAT IS IN THIS TABLE IS NO LONGER PART OF A NEW HARVEST
-- THIS (RECORD) WILL BE REMOVED AND STORED IN A SEPARATE TABLE
CREATE TABLE IF NOT EXISTS testsuite.uris_long
(
    gid SERIAL,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uuid text,
    entity text,
    description text,
    uri text,
    uri_type text,
    eid integer,
    version character varying,
    uri_original text,
    CONSTRAINT uris_long_pkey PRIMARY KEY (gid)
);

-- CREATE TABLE TO STORE CONTAIN/ARCHIVE THE RECORDS THAT WILL BE DELETED FROM THE PREVIOUS TABLE
-- BECAUSE THE SERVICE/URL DOES NOT SHOW ANYMORE IN HARVESTING RESULTS
CREATE TABLE IF NOT EXISTS testsuite.uris_long_deleted
(
    gid SERIAL,
    date_deleted TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uuid text,
    entity text,
    description text,
    uri text,
    uri_type text,
    eid integer,
    version character varying,
    uri_original text,
    CONSTRAINT uris_long_deleted_pkey PRIMARY KEY (gid)
);

-- CREATE TABLE TO STORE TEMPORARLY THE URLS FROM A NEW HARVEST
-- AND THAT WILL BE USED TO COMPARE WITH WHAT ALREADY IS IN THE MAIN TABLE
-- SO TO CHECK WHAT NEEDS TO BE DELETED AND WHAT NEEDS TO BE UPDATED
CREATE TABLE IF NOT EXISTS testsuite.uris_long_temp
(
    gid SERIAL,
    uuid text,
    entity text,
    description text,
    uri text,
    uri_type text,
    eid integer,
    version character varying,
    uri_original text,
    CONSTRAINT uris_long_temp_pkey PRIMARY KEY (gid)
);
