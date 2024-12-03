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
)

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
)

-- CREATE TABLE TO STORE THE entities LIST
CREATE TABLE IF NOT EXISTS testsuite.entities
(
    eid SERIAL,
    description character varying,
    CONSTRAINT entities_pk PRIMARY KEY (eid)
)

-- CREATE TABLE TO STORE GEONETWORK METADATA IN XML FORMAT
CREATE TABLE IF NOT EXISTS testsuite.xml_metadata (
    id SERIAL PRIMARY KEY,
    filename TEXT NOT NULL,
    content XML,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_empty BOOLEAN NOT NULL,
    deleted BOOLEAN DEFAULT FALSE
);
