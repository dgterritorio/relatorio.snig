-- Count the URLs by they http protocol (http vs https vs other)
CREATE OR REPLACE VIEW stats_and_metrics._01_group_urls_by_http_protocol AS
WITH temp AS 
(
SELECT REGEXP_REPLACE("uri_original", ':.*$', '', 'g') AS url_start, 
count(*) AS count
FROM testsuite.uris_long
GROUP BY url_start
ORDER BY url_start
)
SELECT row_number() OVER () AS gid, * FROM temp;


-- Count the URLs by they http status code
CREATE OR REPLACE VIEW stats_and_metrics._02_group_by_http_status_code_global
 AS
 WITH a AS (
         SELECT
                CASE
                    WHEN service_status.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
                    WHEN service_status.exit_info ~~ '%Invalid HTTP status code%'::text THEN "right"(service_status.exit_info, 3)
                    ELSE service_status.exit_info
                END AS status_code,
            count(*) AS count,
            avg(
                CASE
                    WHEN service_status.exit_info ~ 'ping_time: [0-9.]+'::text THEN regexp_replace(service_status.exit_info, '.*ping_time: ([0-9.]+)'::text, '\1'::text)::double precision
                    ELSE NULL::double precision
                END) AS ping_average
           FROM testsuite.service_status
          WHERE service_status.task::text = 'url_status_codes'::text
          GROUP BY (
                CASE
                    WHEN service_status.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
                    WHEN service_status.exit_info ~~ '%Invalid HTTP status code%'::text THEN "right"(service_status.exit_info, 3)
                    ELSE service_status.exit_info
                END)
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.status_code,
                CASE a.status_code
                    WHEN '000'::text THEN 'Timeout'::text
                    WHEN '200'::text THEN 'OK'::text
                    WHEN '201'::text THEN 'Created'::text
                    WHEN '202'::text THEN 'Accepted'::text
                    WHEN '204'::text THEN 'No Content'::text
                    WHEN '301'::text THEN 'Moved Permanently'::text
                    WHEN '302'::text THEN 'Found'::text
                    WHEN '400'::text THEN 'Bad Request'::text
                    WHEN '401'::text THEN 'Unauthorized'::text
                    WHEN '403'::text THEN 'Forbidden'::text
                    WHEN '404'::text THEN 'Not Found'::text
                    WHEN '500'::text THEN 'Internal Server Error'::text
                    WHEN '502'::text THEN 'Bad Gateway'::text
                    WHEN '503'::text THEN 'Service Unavailable'::text
                    WHEN '504'::text THEN 'Gateway Timeout'::text
                    WHEN '499'::text THEN 'Client Closed Request'::text
                    ELSE ''::text
                END AS definition,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT gid,
    status_code,
    definition,
    count,
    ping_average
   FROM temp
  ORDER BY gid;


-- Count the URLs by they http status code and group also by organization
CREATE OR REPLACE VIEW stats_and_metrics._03_group_by_http_status_code_and_entity
 AS
 WITH a AS (
         SELECT
                CASE
                    WHEN b.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
                    WHEN b.exit_info ~~ '%Invalid HTTP status code%'::text THEN "right"(b.exit_info, 3)
                    ELSE b.exit_info
                END AS status_code,
            c.entity,
            count(*) AS count,
            avg(
                CASE
                    WHEN b.exit_info ~~ 'http_status_code: 200%'::text THEN
                    CASE
                        WHEN regexp_replace(b.exit_info, '.*ping_time: ([0-9.]+)'::text, '\1'::text) ~ '^[0-9.]+$'::text THEN regexp_replace(b.exit_info, '.*ping_time: ([0-9.]+)'::text, '\1'::text)::double precision
                        ELSE NULL::double precision
                    END
                    ELSE NULL::double precision
                END) AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'url_status_codes'::text
          GROUP BY c.entity, (
                CASE
                    WHEN b.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
                    WHEN b.exit_info ~~ '%Invalid HTTP status code%'::text THEN "right"(b.exit_info, 3)
                    ELSE b.exit_info
                END)
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.entity,
            a.status_code,
                CASE a.status_code
                    WHEN '000'::text THEN 'Timeout'::text
                    WHEN '200'::text THEN 'OK'::text
                    WHEN '201'::text THEN 'Created'::text
                    WHEN '202'::text THEN 'Accepted'::text
                    WHEN '204'::text THEN 'No Content'::text
                    WHEN '301'::text THEN 'Moved Permanently'::text
                    WHEN '302'::text THEN 'Found'::text
                    WHEN '400'::text THEN 'Bad Request'::text
                    WHEN '401'::text THEN 'Unauthorized'::text
                    WHEN '403'::text THEN 'Forbidden'::text
                    WHEN '404'::text THEN 'Not Found'::text
                    WHEN '500'::text THEN 'Internal Server Error'::text
                    WHEN '502'::text THEN 'Bad Gateway'::text
                    WHEN '503'::text THEN 'Service Unavailable'::text
                    WHEN '504'::text THEN 'Gateway Timeout'::text
                    WHEN '499'::text THEN 'Client Closed Request'::text
                    ELSE ''::text
                END AS definition,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT gid,
    entity,
    status_code,
    definition,
    count,
    ping_average
   FROM temp
  ORDER BY entity, status_code;


-- Count the URLs by they http status code and group also by domain
CREATE OR REPLACE VIEW stats_and_metrics._04_group_by_http_status_code_and_domain AS
WITH a AS 
(
    SELECT 
        -- Extract the status code based on the given conditions
        CASE 
            WHEN b.exit_info LIKE 'http_status_code: 200%' 
            THEN '200'  -- Directly use '200' for matching case
            WHEN b.exit_info LIKE '%Invalid HTTP status code%' 
            THEN RIGHT(b.exit_info, 3)  -- Extract the last 3 characters for invalid cases
            ELSE b.exit_info -- Fallback to the original value
        END AS status_code,
        -- Extract and group by the domain part of the URL, removing protocol and port
        LOWER(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    c.uri_original, 
                    '^https?://',  -- Remove http:// or https://
                    ''
                ), 
                '(:[0-9]+)?/.*$',  -- Remove port number and anything after the domain
                ''
            )
        ) AS uri_domain,  -- Extracted domain
        COUNT(*) AS count,
        AVG(
            CASE 
                WHEN b.exit_info LIKE 'http_status_code: 200%' 
                THEN CAST(REGEXP_REPLACE(b.exit_info, '.*ping_time: ([0-9.]+)', '\1') AS FLOAT)
                ELSE NULL
            END
        ) AS ping_average
    FROM 
        testsuite.service_status b
    INNER JOIN 
        testsuite.uris_long c 
    ON 
        b.gid = c.gid  -- Join on the gid column
    WHERE 
        b.task = 'url_status_codes'
    GROUP BY 
        -- Group by the extracted domain (uri_domain)
        LOWER(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    c.uri_original, 
                    '^https?://',  -- Remove http:// or https://
                    ''
                ), 
                '(:[0-9]+)?/.*$',  -- Remove port number and anything after the domain
                ''
            )
        ),
        CASE 
            WHEN b.exit_info LIKE 'http_status_code: 200%' 
            THEN '200'
            WHEN b.exit_info LIKE '%Invalid HTTP status code%' 
            THEN RIGHT(b.exit_info, 3)
            ELSE b.exit_info
        END
),
temp AS
(
    SELECT 
        row_number() OVER () AS gid,
        a.uri_domain,
        a.status_code,
        -- Add HTTP status code definitions based on Wikipedia
        CASE a.status_code
            WHEN '000' THEN 'Timeout'
            WHEN '200' THEN 'OK'
            WHEN '201' THEN 'Created'
            WHEN '202' THEN 'Accepted'
            WHEN '204' THEN 'No Content'
            WHEN '301' THEN 'Moved Permanently'
            WHEN '302' THEN 'Found'
            WHEN '400' THEN 'Bad Request'
            WHEN '401' THEN 'Unauthorized'
            WHEN '403' THEN 'Forbidden'
            WHEN '404' THEN 'Not Found'
            WHEN '500' THEN 'Internal Server Error'
            WHEN '502' THEN 'Bad Gateway'
            WHEN '503' THEN 'Service Unavailable'
            WHEN '504' THEN 'Gateway Timeout'
            WHEN '499' THEN 'Client Closed Request'
            ELSE '' -- For other codes not explicitly defined
        END AS status_code_definition,
        a.count,
        a.ping_average
    FROM a
)
SELECT * 
FROM temp
ORDER BY uri_domain,status_code;
