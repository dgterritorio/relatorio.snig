-- Ungrouped results. This is just a join between uris_long and service_status
CREATE OR REPLACE VIEW metrics._00_ungrouped_results AS
SELECT b.eid,b.gid,a.task,a.exit_status,a.task_duration FROM testsuite.service_status a 
JOIN testsuite.uris_long b ON a.gid = b.gid
ORDER BY eid,gid,task;

-- URLs listed by protocol (http vs https vs other)
CREATE OR REPLACE VIEW metrics._01_group_urls_by_http_protocol AS
WITH temp AS 
(
    SELECT eid, REGEXP_REPLACE("uri_original",':.*$','','g') AS url_start, 
    count(*) AS count
    FROM testsuite.uris_long
    GROUP BY eid, url_start
    ORDER BY eid, url_start
)
SELECT row_number() OVER () AS gid, * FROM temp;

-- Count the URLs by they http status code and per entity
CREATE OR REPLACE VIEW metrics._02_group_by_http_status_code_global AS
WITH base AS (
  SELECT
    ss.gid, (SELECT ul.eid FROM testsuite.uris_long as ul WHERE ul.gid=ss.gid) AS eid,
    testsuite.exit_info_map(ss.exit_info) as status_code,
    ss.task_duration FROM testsuite.service_status AS ss
    WHERE ss.task = 'url_status_codes'
),
agg AS (
  SELECT eid, status_code,
         COUNT(*) AS count,
         to_char(avg(task_duration)::real,'9990D99') AS ping_average
  FROM base
  GROUP BY eid,status_code
),
ranked AS (
  SELECT
    a.eid,
    ROW_NUMBER() OVER (ORDER BY a.count DESC, a.status_code) AS rid,
    a.status_code,
    COALESCE(l.definition,'') AS status_code_definition,
    a.count,
    a.ping_average
  FROM agg a
  LEFT JOIN LATERAL testsuite.labels() l ON l.code = a.status_code
)
SELECT eid, rid, status_code, status_code_definition, count, ping_average FROM ranked ORDER BY eid, count DESC;

-- Count the URLs by they http status code and group also by domain
CREATE OR REPLACE VIEW metrics._04_group_by_http_status_code_and_domain
 AS
 WITH a AS (
     SELECT
        c.eid, testsuite.exit_info_map(b.exit_info) AS status_code,
        lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text)) AS uri_domain,
        count(*) AS count,
        to_char(avg(b.task_duration)::real,'9990D99') AS ping_average
        FROM testsuite.service_status b JOIN testsuite.uris_long c ON b.gid = c.gid
        WHERE b.task::text = 'url_status_codes'::text
        GROUP BY c.eid,uri_domain,status_code
    ), temp AS (
     SELECT row_number() OVER () AS rid,
        a.eid,
        a.uri_domain,
        a.status_code,
        COALESCE(l.definition,'') as status_code_definition,
        a.count,
        a.ping_average
       FROM a LEFT JOIN LATERAL testsuite.labels() l on l.code = a.status_code
    )
 SELECT rid, eid,
    uri_domain,
    status_code,
    status_code_definition,
    count,
    ping_average
   FROM temp ORDER BY uri_domain, count DESC;


-- Count the URLs by they WMS and WFS Capabilities document validity 
CREATE OR REPLACE VIEW metrics._05_group_by_wms_capabilities_validity_global
 AS
 WITH a AS (
         SELECT
            ul.eid,
			ss.exit_info AS result_message,
			ss.exit_status AS result_code,
            count(*) AS count,
            to_char(avg(ss.task_duration)::real,'9990D99') AS ping_average
          FROM testsuite.service_status AS ss
          JOIN testsuite.uris_long AS ul ON ss.gid = ul.gid
          WHERE ss.task::text = 'wms_capabilities'::text
          GROUP BY ul.eid, ss.exit_info, ss.exit_status
        ), temp AS (
         SELECT a.eid, row_number() OVER () AS rid,
            a.result_code,
            a.result_message,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid, eid,
    result_code,
    result_message,
    count,
    ping_average
   FROM temp
  ORDER BY eid, count desc;


CREATE OR REPLACE VIEW metrics._06_group_by_wfs_capabilities_validity_global
 AS
 WITH a AS (
         SELECT
            ul.eid,
			ss.exit_info AS result_message,
			ss.exit_status AS result_code,
            count(*) AS count,
            to_char(avg(ss.task_duration)::real,'9990D99') AS ping_average
          FROM testsuite.service_status AS ss
          JOIN testsuite.uris_long AS ul ON ss.gid = ul.gid
          WHERE ss.task::text = 'wfs_capabilities'::text
          GROUP BY ul.eid, ss.exit_info, ss.exit_status 
        ), temp AS (
         SELECT a.eid, row_number() OVER () AS rid,
            a.result_code,
            a.result_message,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid, eid,
    result_code,
    result_message,
    count,
    ping_average
 FROM temp
 ORDER BY eid, count desc;

-- Count the URLs by they WMS/WFS Capabilities XML document validity and group also by organization
CREATE OR REPLACE VIEW metrics._07_group_by_wms_capabilities_validity_and_entity
 AS
 WITH a AS (
         SELECT
            c.eid,
			b.exit_info AS result_message,
			b.exit_status AS result_code,
            count(*) AS count,
            to_char(avg(b.task_duration)::real,'9990D99') AS ping_average
          FROM testsuite.service_status b
		  JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wms_capabilities'::text
          GROUP BY c.eid, b.exit_info, b.exit_status 
        ), temp AS (
         SELECT row_number() OVER () AS rid,
            a.eid,
            a.result_code,
            a.result_message,
            a.count,
            a.ping_average
           FROM a
        )
     SELECT rid, eid,
            result_code,
            result_message,
            count,
            ping_average
            FROM temp ORDER BY eid, count desc;

CREATE OR REPLACE VIEW metrics._08_group_by_wfs_capabilities_validity_and_entity
 AS
 WITH a AS (
         SELECT
			b.exit_info AS result_message,
			b.exit_status AS result_code,
			c.eid,
            count(*) AS count,
            to_char(avg(b.task_duration)::real,'9990D99') AS ping_average
          FROM testsuite.service_status b
		  JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wfs_capabilities'::text
          GROUP BY c.eid, b.exit_status, b.exit_info
        ), temp AS (
         SELECT row_number() OVER () AS rid,
		    a.eid,
            a.result_code,
            a.result_message,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid,
        eid,
        result_code,
        result_message,
        count,
        ping_average
   FROM temp
  ORDER BY eid, count desc;

-- Count the URLs by they WMS/WFS Capabilities XML document validity and group also by domain
CREATE OR REPLACE VIEW metrics._09_group_by_wms_capabilities_validity_and_domain
 AS
 WITH a AS (
         SELECT b.exit_info,
            b.exit_status, c.eid,
            lower(regexp_replace(regexp_replace(c.uri_original,'^https?://'::text, ''::text),'(:[0-9]+)?/.*$'::text,''::text)) AS uri_domain,
            count(*) AS count,
            to_char(avg(b.task_duration)::real,'9990D99') AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wms_capabilities'::text
          GROUP BY c.eid,uri_domain, b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS rid,
            a.eid,
            a.uri_domain,
            a.exit_info AS result_message,
            a.exit_status AS result_code,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid, eid,
    uri_domain,
    result_code,
    result_message,
    count,
    ping_average
   FROM temp
  ORDER BY uri_domain, count DESC;


CREATE OR REPLACE VIEW metrics._10_group_by_wfs_capabilities_validity_and_domain
 AS
 WITH a AS (
    SELECT b.exit_info, b.exit_status, c.eid,
       lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text)) AS uri_domain,
            count(*) AS count,
            to_char(avg(b.task_duration)::real,'9990D99') AS ping_average
           FROM testsuite.service_status b JOIN testsuite.uris_long c ON b.gid = c.gid
           WHERE b.task::text = 'wfs_capabilities'::text
           GROUP BY c.eid,uri_domain, b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS rid,
            a.eid,
            a.uri_domain,
            a.exit_info AS result_message,
            a.exit_status AS result_code,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid, eid,
    uri_domain,
    result_message,
    result_code,
    count,
    ping_average
 FROM temp ORDER BY uri_domain, count DESC;


-- Count the URLs by they WMS and WFS gdal_info/ogr_info response validity 
CREATE OR REPLACE VIEW metrics._11_group_by_wms_gdal_info_validity_global
 AS
 WITH a AS (
         SELECT ul.eid,ss.exit_info,
            ss.exit_status,
            count(*) AS count,
            to_char(avg(ss.task_duration)::real,'9990D99') AS ping_average
           FROM testsuite.service_status AS ss
           JOIN testsuite.uris_long AS ul ON ul.gid = ss.gid
          WHERE ss.task::text = 'wms_gdal_info'::text
          GROUP BY ul.eid,ss.exit_info,ss.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS rid,
            a.eid,
            a.exit_info AS result_message,
            a.exit_status AS result_code,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid, eid, (SELECT ent.description FROM testsuite.entities AS ent WHERE ent.eid=temp.eid) entity,
    result_code,
    result_message,
    count,
    ping_average
   FROM temp
  ORDER BY entity, count DESC;

CREATE OR REPLACE VIEW metrics._12_group_by_wfs_ogr_info_validity_global
 AS
 WITH a AS (
        SELECT 
            ul.eid,
            CASE
                WHEN ss.exit_info = 'valid WFS OGR info response (version 1.0.0)'::text THEN 'valid WFS OGR info response (version 1.0.0)'::text
                WHEN ss.exit_info = 'valid WFS OGR info response (version 1.1.0)'::text THEN 'valid WFS OGR info response (version 1.1.0)'::text
                WHEN ss.exit_info = 'valid WFS OGR info response (version 2.0.0)'::text THEN 'valid WFS OGR info response (version 2.0.0)'::text
                WHEN ss.exit_info = 'Service exception or error'::text THEN 'Service exception or error'::text
                WHEN ss.exit_info ~~ 'Service exception or error (%'::text THEN 'Non fatal exception/error'::text
                ELSE ss.exit_info
            END, 
            ss.exit_status,
            count(*) AS count,
            to_char(avg(ss.task_duration)::real,'9990D99') AS ping_average
           FROM testsuite.service_status AS ss
           JOIN testsuite.uris_long AS ul ON ul.gid = ss.gid
          WHERE ss.task::text = 'wfs_ogr_info'::text
          GROUP BY ul.eid, ss.exit_status, ss.exit_info
    ), temp AS (
         SELECT row_number() OVER () AS rid,
            a.eid,
            a.exit_info AS result_message,
            a.exit_status AS result_code,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid, eid, (SELECT ent.description FROM testsuite.entities AS ent WHERE ent.eid=temp.eid) entity,
    result_message,
    result_code,
    count,
    ping_average
   FROM temp
  ORDER BY entity, count DESC;

-- Count the URLs by they WMS and WFS gdal_info/ogr_info response validity and group also by organization
CREATE OR REPLACE VIEW metrics._13_group_by_wms_gdal_info_validity_and_entity
 AS
 WITH a AS (
         SELECT b.exit_info,
            b.exit_status,
            c.eid,
            count(*) AS count,
            to_char(avg(b.task_duration)::real,'9990D99') AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wms_gdal_info'::text
          GROUP BY c.eid, b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS rid,
            a.eid,
            (SELECT entities.description FROM testsuite.entities WHERE entities.eid=a.eid) entity,
            a.exit_info AS result_message,
            a.exit_status AS result_code,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid,
    eid,
    entity,
    result_message,
    result_code,
    count,
    ping_average
   FROM temp
  ORDER BY entity, count DESC;
  
CREATE OR REPLACE VIEW metrics._14_group_by_wfs_ogr_info_validity_and_entity
    AS
    WITH a AS (
         SELECT b.exit_info,
            b.exit_status,
            c.eid,
            count(*) AS count,
            to_char(avg(b.task_duration)::real,'9990D99') AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wfs_ogr_info'::text
          GROUP BY c.eid, b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS rid,
            a.eid,
            (SELECT entities.description FROM testsuite.entities WHERE entities.eid=a.eid) entity,
            a.exit_info AS result_message,
            a.exit_status AS result_code,
            a.count,
            a.ping_average
           FROM a
        )
    SELECT  rid,
            entity,
            result_code,
            result_message,
            count,
            ping_average
   FROM temp
  ORDER BY entity, count DESC;

-- Count the URLs by they WMS and WFS gdal_info/ogr_info response validity and group also by domain
CREATE OR REPLACE VIEW metrics._15_group_by_wms_gdal_info_validity_and_domain
 AS
 WITH a AS (
         SELECT b.exit_info,
            b.exit_status,
            c.eid,
            lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text)) AS uri_domain,
            count(*) AS count,
            to_char(avg(b.task_duration)::real,'9990D99') AS ping_average
           FROM testsuite.service_status b JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wms_gdal_info'::text
          GROUP BY c.eid, uri_domain, b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS rid,
            a.eid,
            a.uri_domain,
            a.exit_info AS result_message,
            a.exit_status AS result_code,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid, eid,
    uri_domain,
    result_code,
    result_message,
    count,
    ping_average
   FROM temp
  ORDER BY uri_domain, count DESC;


CREATE OR REPLACE VIEW metrics._16_group_by_wfs_ogr_info_validity_and_domain
 AS
 WITH a AS (
         SELECT b.exit_info,
            b.exit_status,
            c.eid,
            lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text)) AS uri_domain,
            count(*) AS count,
            to_char(avg(b.task_duration)::real,'9990D99') AS ping_average
           FROM testsuite.service_status b JOIN testsuite.uris_long c ON b.gid = c.gid
           WHERE b.task::text = 'wfs_ogr_info'::text
           GROUP BY c.eid,uri_domain,b.exit_info,b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS rid,
            a.eid,
            a.uri_domain,
            a.exit_info AS result_message,
            a.exit_status AS result_code,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT rid, eid,
    uri_domain,
    result_code,
    result_message,
    count,
    ping_average
   FROM temp
  ORDER BY uri_domain, count DESC;
