-- ============================================================
-- VIEW: metrics._00_ungrouped_results
-- PURPOSE: Join service_status and uris_long to produce raw, ungrouped data
-- ============================================================
CREATE OR REPLACE VIEW metrics._00_ungrouped_results AS
SELECT 
    b.eid,
    b.gid,
    a.task,
    a.exit_status,
    a.task_duration
FROM testsuite.service_status a
JOIN testsuite.uris_long b ON a.gid = b.gid
ORDER BY eid, gid, task;


-- ============================================================
-- VIEW: metrics._01_group_urls_by_http_protocol
-- PURPOSE: Group URLs by HTTP protocol type (http, https, etc.)
-- ============================================================
CREATE OR REPLACE VIEW metrics._01_group_urls_by_http_protocol AS
WITH temp AS (
    SELECT 
        eid,
        REGEXP_REPLACE("uri_original", ':.*$', '', 'g') AS url_start,
        COUNT(*) AS count
    FROM testsuite.uris_long
    GROUP BY eid, url_start
    ORDER BY eid, url_start
)
SELECT 
    ROW_NUMBER() OVER () AS gid, 
    * 
FROM temp;


-- ============================================================
-- VIEW: metrics._02_group_by_http_status_code_global
-- PURPOSE: Aggregate URL counts by HTTP status code per entity
-- ============================================================
CREATE OR REPLACE VIEW metrics._02_group_by_http_status_code_global AS
WITH base AS (
    SELECT
        ss.gid,
        (SELECT ul.eid FROM testsuite.uris_long AS ul WHERE ul.gid = ss.gid) AS eid,
        testsuite.exit_info_map(ss.exit_info) AS status_code,
        ss.task_duration
    FROM testsuite.service_status AS ss
    WHERE ss.task = 'url_status_codes'
),
agg AS (
    SELECT 
        eid, 
        status_code,
        COUNT(*) AS count,
        TO_CHAR(AVG(task_duration)::real, '9990D99') AS ping_average
    FROM base
    GROUP BY eid, status_code
),
ranked AS (
    SELECT
        a.eid,
        ROW_NUMBER() OVER (ORDER BY a.count DESC, a.status_code) AS rid,
        a.status_code,
        COALESCE(l.definition, '') AS status_code_definition,
        a.count,
        a.ping_average
    FROM agg a
    LEFT JOIN LATERAL testsuite.labels() l ON l.code = a.status_code
)
SELECT 
    eid, 
    rid, 
    status_code, 
    status_code_definition, 
    count, 
    ping_average
FROM ranked
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._04_group_by_http_status_code_and_domain
-- PURPOSE: Aggregate URLs by HTTP status code and domain
-- ============================================================
CREATE OR REPLACE VIEW metrics._04_group_by_http_status_code_and_domain AS
WITH a AS (
    SELECT
        c.eid,
        testsuite.exit_info_map(b.exit_info) AS status_code,
        LOWER(REGEXP_REPLACE(
            REGEXP_REPLACE(c.uri_original, '^https?://', ''),
            '(:[0-9]+)?/.*$', ''
        )) AS uri_domain,
        COUNT(*) AS count,
        TO_CHAR(AVG(b.task_duration)::real, '9990D99') AS ping_average
    FROM testsuite.service_status b
    JOIN testsuite.uris_long c ON b.gid = c.gid
    WHERE b.task::text = 'url_status_codes'::text
    GROUP BY c.eid, uri_domain, status_code
),
temp AS (
    SELECT 
        ROW_NUMBER() OVER () AS rid,
        a.eid,
        a.uri_domain,
        a.status_code,
        COALESCE(l.definition, '') AS status_code_definition,
        a.count,
        a.ping_average
    FROM a
    LEFT JOIN LATERAL testsuite.labels() l ON l.code = a.status_code
)
SELECT 
    rid, 
    eid,
    uri_domain,
    status_code,
    status_code_definition,
    count,
    ping_average
FROM temp
ORDER BY uri_domain, count DESC;


-- ============================================================
-- VIEW: metrics._05_group_by_wms_capabilities_validity_global
-- PURPOSE: Aggregate WMS Capabilities validation results globally
-- ============================================================
CREATE OR REPLACE VIEW metrics._05_group_by_wms_capabilities_validity_global AS
WITH a AS (
    SELECT
        ul.eid,
        ss.exit_info AS result_message,
        ss.exit_status AS result_code,
        COUNT(*) AS count,
        TO_CHAR(AVG(ss.task_duration)::real, '9990D99') AS ping_average
    FROM testsuite.service_status AS ss
    JOIN testsuite.uris_long AS ul ON ss.gid = ul.gid
    WHERE ss.task::text = 'wms_capabilities'::text
    GROUP BY ul.eid, ss.exit_info, ss.exit_status
),
temp AS (
    SELECT 
        a.eid, 
        ROW_NUMBER() OVER () AS rid,
        a.result_code,
        a.result_message,
        a.count,
        a.ping_average
    FROM a
)
SELECT 
    rid, 
    eid,
    result_code,
    result_message,
    count,
    ping_average
FROM temp
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._06_group_by_wfs_capabilities_validity_global
-- PURPOSE: Aggregate WFS Capabilities validation results globally
-- ============================================================
CREATE OR REPLACE VIEW metrics._06_group_by_wfs_capabilities_validity_global AS
WITH a AS (
    SELECT
        ul.eid,
        ss.exit_info AS result_message,
        ss.exit_status AS result_code,
        COUNT(*) AS count,
        TO_CHAR(AVG(ss.task_duration)::real, '9990D99') AS ping_average
    FROM testsuite.service_status AS ss
    JOIN testsuite.uris_long AS ul ON ss.gid = ul.gid
    WHERE ss.task::text = 'wfs_capabilities'::text
    GROUP BY ul.eid, ss.exit_info, ss.exit_status
),
temp AS (
    SELECT 
        a.eid, 
        ROW_NUMBER() OVER () AS rid,
        a.result_code,
        a.result_message,
        a.count,
        a.ping_average
    FROM a
)
SELECT 
    rid, 
    eid,
    result_code,
    result_message,
    count,
    ping_average
FROM temp
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._07_group_by_wms_capabilities_validity_and_entity
-- PURPOSE: Group WMS Capabilities validation by organization
-- ============================================================
CREATE OR REPLACE VIEW metrics._07_group_by_wms_capabilities_validity_and_entity AS
WITH a AS (
    SELECT
        c.eid,
        b.exit_info AS result_message,
        b.exit_status AS result_code,
        COUNT(*) AS count,
        TO_CHAR(AVG(b.task_duration)::real, '9990D99') AS ping_average
    FROM testsuite.service_status b
    JOIN testsuite.uris_long c ON b.gid = c.gid
    WHERE b.task::text = 'wms_capabilities'::text
    GROUP BY c.eid, b.exit_info, b.exit_status
),
temp AS (
    SELECT 
        ROW_NUMBER() OVER () AS rid,
        a.eid,
        a.result_code,
        a.result_message,
        a.count,
        a.ping_average
    FROM a
)
SELECT 
    rid, 
    eid,
    result_code,
    result_message,
    count,
    ping_average
FROM temp
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._08_group_by_wfs_capabilities_validity_and_entity
-- PURPOSE: Group WFS Capabilities validation by organization
-- ============================================================
CREATE OR REPLACE VIEW metrics._08_group_by_wfs_capabilities_validity_and_entity AS
WITH a AS (
    SELECT
        b.exit_info AS result_message,
        b.exit_status AS result_code,
        c.eid,
        COUNT(*) AS count,
        TO_CHAR(AVG(b.task_duration)::real, '9990D99') AS ping_average
    FROM testsuite.service_status b
    JOIN testsuite.uris_long c ON b.gid = c.gid
    WHERE b.task::text = 'wfs_capabilities'::text
    GROUP BY c.eid, b.exit_status, b.exit_info
),
temp AS (
    SELECT 
        ROW_NUMBER() OVER () AS rid,
        a.eid,
        a.result_code,
        a.result_message,
        a.count,
        a.ping_average
    FROM a
)
SELECT 
    rid,
    eid,
    result_code,
    result_message,
    count,
    ping_average
FROM temp
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._09_group_by_wms_maprequest_validity_global
-- PURPOSE: Aggregate WMS map request validation results globally
-- ============================================================
CREATE OR REPLACE VIEW metrics._09_group_by_wms_maprequest_validity_global AS
WITH a AS (
    SELECT
        ul.eid,
        ss.exit_info AS result_message,
        ss.exit_status AS result_code,
        COUNT(*) AS count,
        TO_CHAR(AVG(ss.task_duration)::real, '9990D99') AS ping_average
    FROM testsuite.service_status AS ss
    JOIN testsuite.uris_long AS ul ON ss.gid = ul.gid
    WHERE ss.task::text = 'wms_maprequest'::text
    GROUP BY ul.eid, ss.exit_info, ss.exit_status
),
temp AS (
    SELECT
        a.eid,
        ROW_NUMBER() OVER () AS rid,
        a.result_code,
        a.result_message,
        a.count,
        a.ping_average
    FROM a
)
SELECT
    rid,
    eid,
    result_code,
    result_message,
    count,
    ping_average
FROM temp
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._10_group_by_wms_maprequest_validity_and_entity
-- PURPOSE: Group WMS map request validation by organization
-- ============================================================
CREATE OR REPLACE VIEW metrics._10_group_by_wms_maprequest_validity_and_entity AS
WITH a AS (
    SELECT
        c.eid,
        b.exit_info AS result_message,
        b.exit_status AS result_code,
        COUNT(*) AS count,
        TO_CHAR(AVG(b.task_duration)::real, '9990D99') AS ping_average
    FROM testsuite.service_status b
    JOIN testsuite.uris_long c ON b.gid = c.gid
    WHERE b.task::text = 'wms_maprequest'::text
    GROUP BY c.eid, b.exit_info, b.exit_status
),
temp AS (
    SELECT
        ROW_NUMBER() OVER () AS rid,
        a.eid,
        a.result_code,
        a.result_message,
        a.count,
        a.ping_average
    FROM a
)
SELECT
    rid,
    eid,
    result_code,
    result_message,
    count,
    ping_average
FROM temp
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._11_group_by_arcgis_validity_global
-- PURPOSE: Aggregate ArcGIS service validation results globally
-- ============================================================
CREATE OR REPLACE VIEW metrics._11_group_by_arcgis_validity_global AS
WITH a AS (
    SELECT
        ul.eid,
        ss.exit_info AS result_message,
        ss.exit_status AS result_code,
        COUNT(*) AS count,
        TO_CHAR(AVG(ss.task_duration)::real, '9990D99') AS ping_average
    FROM testsuite.service_status AS ss
    JOIN testsuite.uris_long AS ul ON ss.gid = ul.gid
    WHERE ss.task = 'arcgis_validation'
    GROUP BY ul.eid, ss.exit_info, ss.exit_status
),
temp AS (
    SELECT
        a.eid,
        ROW_NUMBER() OVER () AS rid,
        a.result_code,
        a.result_message,
        a.count,
        a.ping_average
    FROM a
)
SELECT
    rid,
    eid,
    result_code,
    result_message,
    count,
    ping_average
FROM temp
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._12_group_by_arcgis_validity_and_entity
-- PURPOSE: Group ArcGIS validation results by organization
-- ============================================================
CREATE OR REPLACE VIEW metrics._12_group_by_arcgis_validity_and_entity AS
WITH a AS (
    SELECT
        c.eid,
        b.exit_info AS result_message,
        b.exit_status AS result_code,
        COUNT(*) AS count,
        TO_CHAR(AVG(b.task_duration)::real, '9990D99') AS ping_average
    FROM testsuite.service_status b
    JOIN testsuite.uris_long c ON b.gid = c.gid
    WHERE b.task::text = 'arcgis_validation'::text
    GROUP BY c.eid, b.exit_info, b.exit_status
),
temp AS (
    SELECT
        ROW_NUMBER() OVER () AS rid,
        a.eid,
        a.result_code,
        a.result_message,
        a.count,
        a.ping_average
    FROM a
)
SELECT
    rid,
    eid,
    result_code,
    result_message,
    count,
    ping_average
FROM temp
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._13_group_by_url_type
-- PURPOSE: Group URLs by their detected type (WMS, WFS, ArcGIS, etc.)
-- ============================================================
CREATE OR REPLACE VIEW metrics._13_group_by_url_type AS
WITH temp AS (
    SELECT
        eid,
        uri_type,
        COUNT(*) AS count
    FROM testsuite.uris_long
    GROUP BY eid, uri_type
)
SELECT
    ROW_NUMBER() OVER () AS gid,
    eid,
    uri_type,
    count
FROM temp
ORDER BY eid, count DESC;


-- ============================================================
-- VIEW: metrics._14_group_by_services_per_entity
-- PURPOSE: Count number of services per entity
-- ============================================================
CREATE OR REPLACE VIEW metrics._14_group_by_services_per_entity AS
WITH temp AS (
    SELECT
        eid,
        COUNT(DISTINCT uuid) AS services_count
    FROM testsuite.uris_long
    GROUP BY eid
)
SELECT
    ROW_NUMBER() OVER () AS rid,
    eid,
    services_count
FROM temp
ORDER BY services_count DESC;


-- ============================================================
-- VIEW: metrics._15_group_by_removed_urls
-- PURPOSE: List URLs removed from active tests (archived in uris_long_deleted)
-- ============================================================
CREATE OR REPLACE VIEW metrics._15_group_by_removed_urls AS
WITH temp AS (
    SELECT
        eid,
        COUNT(*) AS removed_count
    FROM testsuite.uris_long_deleted
    GROUP BY eid
)
SELECT
    ROW_NUMBER() OVER () AS rid,
    eid,
    removed_count
FROM temp
ORDER BY removed_count DESC;


-- ============================================================
-- VIEW: metrics._16_summary_entity_status
-- PURPOSE: Summarize per-entity total, removed, and active URLs
-- ============================================================
CREATE OR REPLACE VIEW metrics._16_summary_entity_status AS
WITH active AS (
    SELECT eid, COUNT(*) AS active_count
    FROM testsuite.uris_long
    GROUP BY eid
),
removed AS (
    SELECT eid, COUNT(*) AS removed_count
    FROM testsuite.uris_long_deleted
    GROUP BY eid
)
SELECT
    e.eid,
    COALESCE(a.active_count, 0) AS active_count,
    COALESCE(r.removed_count, 0) AS removed_count,
    (COALESCE(a.active_count, 0) + COALESCE(r.removed_count, 0)) AS total_urls
FROM testsuite.entities e
LEFT JOIN active a ON a.eid = e.eid
LEFT JOIN removed r ON r.eid = e.eid
ORDER BY e.eid;
