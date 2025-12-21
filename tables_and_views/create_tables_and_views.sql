-- ============================================================
-- DATABASE SCHEMAS
-- ============================================================
CREATE SCHEMA testsuite;
CREATE SCHEMA stats;

-- ============================================================
-- TABLE: testsuite.service_status
-- DESCRIPTION: Stores the latest status of the monitor for each service/task
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.service_status (
    gid           INTEGER                NOT NULL,
    ts            TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    task          VARCHAR                NOT NULL,
    exit_status   VARCHAR                NOT NULL,
    exit_info     TEXT,
    uuid          VARCHAR,
    CONSTRAINT service_status_unique UNIQUE (gid, task)
);

-- ============================================================
-- TABLE: testsuite.service_log
-- DESCRIPTION: Stores the complete log of monitor results
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.service_log (
    entryid       SERIAL,
    gid           INTEGER                NOT NULL,
    ts            TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    task          VARCHAR                NOT NULL,
    exit_status   VARCHAR                NOT NULL,
    exit_info     TEXT,
    uuid          VARCHAR
);

-- ============================================================
-- TABLE: testsuite.service_log_deleted
-- DESCRIPTION: Stores deleted records from the service_log table
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.service_log_deleted (
    entryid       SERIAL,
    gid           INTEGER                NOT NULL,
    date_deleted  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ts            TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    task          VARCHAR                NOT NULL,
    exit_status   VARCHAR                NOT NULL,
    exit_info     TEXT,
    uuid          VARCHAR
);

-- ============================================================
-- TABLE: testsuite.entities
-- DESCRIPTION: Stores the list of entities
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.entities (
    eid           SERIAL,
    description   VARCHAR,
    CONSTRAINT entities_pk PRIMARY KEY (eid)
);

-- ============================================================
-- TABLE: testsuite.xml_metadata
-- DESCRIPTION: Stores GeoNetwork metadata in XML format
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.xml_metadata (
    id            SERIAL PRIMARY KEY,
    filename      TEXT                  NOT NULL,
    content       XML,
    date_added    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_empty      BOOLEAN               NOT NULL,
    deleted       BOOLEAN DEFAULT FALSE
);

-- ============================================================
-- TABLE: testsuite.uris_wide
-- DESCRIPTION: Stores GeoNetwork record service URLs (wide format)
--              Contains only the results of the last harvest
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.uris_wide (
    gid           SERIAL,
    date_added    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uuid          TEXT,
    entity        TEXT,
    description   TEXT,
    uri1          TEXT,
    uri2          TEXT,
    uri3          TEXT,
    uri4          TEXT,
    uri5          TEXT,
    uri6          TEXT,
    uri7          TEXT,
    uri8          TEXT,
    uri9          TEXT,
    uri10         TEXT,
    uri11         TEXT,
    uri12         TEXT,
    uri13         TEXT,
    CONSTRAINT uris_wide_pkey PRIMARY KEY (gid)
);

-- ============================================================
-- TABLE: testsuite.uris_wide_all
-- DESCRIPTION: Stores GeoNetwork record service URLs (wide format)
--              Contains results of all harvests
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.uris_wide_all (
    gid           SERIAL,
    date_added    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uuid          TEXT,
    entity        TEXT,
    description   TEXT,
    uri1          TEXT,
    uri2          TEXT,
    uri3          TEXT,
    uri4          TEXT,
    uri5          TEXT,
    uri6          TEXT,
    uri7          TEXT,
    uri8          TEXT,
    uri9          TEXT,
    uri10         TEXT,
    uri11         TEXT,
    uri12         TEXT,
    uri13         TEXT,
    CONSTRAINT uris_wide_all_pkey PRIMARY KEY (gid)
);

-- ============================================================
-- TABLE: testsuite.uris_long
-- DESCRIPTION: Stores incremental (non-repeated) list of harvested URLs
--              Records are removed if a URL disappears from new harvest results
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.uris_long (
    gid           SERIAL,
    date_added    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uuid          TEXT,
    entity        TEXT,
    description   TEXT,
    uri           TEXT,
    uri_type      TEXT,
    eid           INTEGER,
    version       VARCHAR,
    uri_original  TEXT,
    CONSTRAINT uris_long_pkey PRIMARY KEY (gid)
);

-- ============================================================
-- TABLE: testsuite.uris_long_deleted
-- DESCRIPTION: Stores archived records removed from uris_long
--              (URLs no longer present in new harvests)
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.uris_long_deleted (
    gid           SERIAL,
    date_deleted  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uuid          TEXT,
    entity        TEXT,
    description   TEXT,
    uri           TEXT,
    uri_type      TEXT,
    eid           INTEGER,
    version       VARCHAR,
    uri_original  TEXT,
    CONSTRAINT uris_long_deleted_pkey PRIMARY KEY (gid)
);

-- ============================================================
-- TABLE: testsuite.uris_long_temp
-- DESCRIPTION: Temporary table to store URLs from new harvests
--              Used for comparison against main tables
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.uris_long_temp (
    gid           SERIAL,
    uuid          TEXT,
    entity        TEXT,
    description   TEXT,
    uri           TEXT,
    uri_type      TEXT,
    eid           INTEGER,
    version       VARCHAR,
    uri_original  TEXT,
    CONSTRAINT uris_long_temp_pkey PRIMARY KEY (gid)
);

-- ============================================================
-- TABLE: testsuite.entities_email_reports
-- DESCRIPTION: Stores entity managers' names and email addresses
-- ============================================================
CREATE TABLE IF NOT EXISTS testsuite.entities_email_reports (
    gid              SERIAL,
    entity           TEXT,
    manager          TEXT,
    email            TEXT,
    services_number  INTEGER,
    eid              INTEGER,
    CONSTRAINT entities_email_reports_pkey PRIMARY KEY (gid)
);
