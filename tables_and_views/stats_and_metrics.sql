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
SELECT left(exit_info,21) AS status_code, 
count(*) AS count
FROM testsuite.service_status
WHERE task = 'url_status_codes' AND exit_info LIKE 'http_status_code: 200%'
GROUP BY status_code
UNION
SELECT exit_info AS status_code,
count(*) AS count
FROM testsuite.service_status
WHERE task = 'url_status_codes' AND exit_info NOT LIKE 'http_status_code: 200%'
GROUP BY status_code

)
SELECT row_number() OVER () AS gid, * FROM temp
ORDER BY gid;
