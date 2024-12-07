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
CREATE OR REPLACE VIEW stats_and_metrics._02_group_by_http_status_code_global AS
WITH temp AS 
(
    SELECT 
        -- Extract the status code based on the given conditions
        CASE 
            WHEN exit_info LIKE 'http_status_code: 200%' 
            THEN '200'  -- Directly use '200' for matching case
            WHEN exit_info LIKE '%Invalid HTTP status code%' 
            THEN RIGHT(exit_info, 3)  -- Extract the last 3 characters for invalid cases
            ELSE exit_info -- Fallback to the original value
        END AS status_code,
        COUNT(*) AS count,
        AVG(
            CASE 
                WHEN exit_info LIKE 'http_status_code: 200%' 
                THEN CAST(REGEXP_REPLACE(exit_info, '.*ping_time: ([0-9.]+)', '\1') AS FLOAT)
                ELSE NULL
            END
        ) AS ping_average
    FROM testsuite.service_status
    WHERE task = 'url_status_codes'
    GROUP BY 
        CASE 
            WHEN exit_info LIKE 'http_status_code: 200%' 
            THEN '200'
            WHEN exit_info LIKE '%Invalid HTTP status code%' 
            THEN RIGHT(exit_info, 3)
            ELSE exit_info
        END
),
final AS
(
    SELECT 
        row_number() OVER () AS gid,
        status_code,
        -- Add HTTP status code definitions based on Wikipedia
        CASE status_code
            WHEN '000' THEN ''  -- No specific description
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
        END AS definition,
        count,
        ping_average
    FROM temp
)
SELECT * 
FROM final
ORDER BY gid;

-- Count the URLs by they http status code and group also by organization
CREATE OR REPLACE VIEW stats_and_metrics._03_group_by_http_status_code_and_entity AS
WITH temp AS 
(
SELECT 
    LEFT(a.exit_info, 21) AS status_code, 
    b.entity, 
    COUNT(*) AS count
FROM 
    testsuite.service_status a
JOIN 
    testsuite.uris_long b
ON 
    a.uuid = b.uuid
WHERE 
    a.task = 'url_status_codes' 
    AND a.exit_info LIKE 'http_status_code: 200%'
GROUP BY 
    status_code, b.entity

UNION

SELECT 
    a.exit_info AS status_code, 
    b.entity, 
    COUNT(*) AS count
FROM 
    testsuite.service_status a
JOIN 
    testsuite.uris_long b
ON 
    a.uuid = b.uuid
WHERE 
    a.task = 'url_status_codes' 
    AND a.exit_info NOT LIKE 'http_status_code: 200%'
GROUP BY 
    status_code, b.entity
ORDER BY 
    status_code, entity
)
SELECT row_number() OVER () AS gid, * FROM temp
ORDER BY entity,status_code;
