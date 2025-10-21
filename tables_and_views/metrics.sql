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
    CASE
      WHEN ss.exit_info = 'Curl got nothing from the server' THEN 'Empty response'
      WHEN ss.exit_info = 'An error occurred during the SSL/TLS handshake' THEN 'SSL error'
      WHEN ss.exit_info LIKE 'http_status_code: 200%' THEN '200'
      WHEN ss.exit_info = 'Invalid HTTP status code 0' THEN 'Status code 0'
      WHEN ss.exit_info = 'Failure in receiving network data' THEN 'Network error'
      WHEN ss.exit_info = 'Failed to connect to host' THEN 'Cannot connect to host'
      WHEN ss.exit_info = 'Peer certificate cannot be authenticated with known CA certificates' THEN 'Certificates error'
      WHEN ss.exit_info LIKE 'Success with http code 200 after redir%' THEN '200 after 301/302 redirect'
      WHEN ss.exit_info IN ('Invalid HTTP status code 301 after redir',
                         'Invalid HTTP status code 302 after redir')
        THEN 'Error HTTP status code after redirect'
      WHEN ss.exit_info LIKE 'Invalid HTTP status code%'
           AND ss.exit_info NOT IN ('Invalid HTTP status code 301 after redir',
                                 'Invalid HTTP status code 302 after redir')
        THEN COALESCE(NULLIF(SUBSTRING(ss.exit_info FROM '(\d{3})$'), ''), ss.exit_info)
      ELSE ss.exit_info
    END AS status_code,
    ss.task_duration FROM testsuite.service_status AS ss
    WHERE ss.task = 'url_status_codes'
),
agg AS (
  SELECT eid, status_code,
         COUNT(*) AS count,
         AVG(task_duration) AS ping_average
  FROM base
  GROUP BY eid,status_code
),
labels(code, definition) AS (
  VALUES
    ('Empty response','Empty response'),
    ('SSL error','SSL error'),
    ('000','Timeout'),
    ('URL status code check failed on a 20 secs timeout error','Timeout'),
    ('200','OK'),
    ('200 after 301/302 redirect','OK after redirect'),
    ('201','Created'),
    ('202','Accepted'),
    ('204','No Content'),
    ('301','Moved Permanently'),
    ('302','Found'),
    ('Error HTTP status code after redirect','Error after redirect'),
    ('400','Bad Request'),
    ('401','Unauthorized'),
    ('403','Forbidden'),
    ('404','Not Found'),
    ('500','Internal Server Error'),
    ('502','Bad Gateway'),
    ('503','Service Unavailable'),
    ('504','Gateway Timeout'),
    ('499','Client Closed Request'),
    ('Error resolving the URL host name','Hostname unknown'),
    ('Network error','Network error'),
    ('Cannot connect to host','Cannot connect to host'),
    ('Certificates error','Certificates error'),
    ('Status code 0','To be investigated')
),
ranked AS (
  SELECT
    a.eid,
    ROW_NUMBER() OVER (ORDER BY a.count DESC, a.status_code) AS rid,
    a.status_code,
    COALESCE(l.definition, '') AS definition,
    a.count,
    a.ping_average
  FROM agg a
  LEFT JOIN labels l ON l.code = a.status_code
)
SELECT eid, rid, status_code, definition, count, ping_average FROM ranked ORDER BY eid, count DESC;


