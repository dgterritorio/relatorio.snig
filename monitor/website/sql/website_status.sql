ALTER TABLE testsuite.entities_email_reports ADD COLUMN hash CHARACTER(16);
CREATE TABLE testsuite.website_status(
    hostid                SERIAL,
    hostname              VARCHAR,
    login_count           integer DEFAULT 0,
    hash_regenerate_count integer DEFAULT 0
);
