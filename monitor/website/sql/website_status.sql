CREATE TABLE testsuite.website_status(
    hostid                SERIAL,
    hostname              VARCHAR,
    login_count           integer DEFAULT 0,
    hash_regenerate_count integer DEFAULT 0
);
