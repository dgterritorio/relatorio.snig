-- Ungrouped results
CREATE OR REPLACE VIEW stats_and_metrics._00_ungrouped_results AS
SELECT b.entity,b.uri,a.task,a.exit_status,a.task_duration FROM testsuite.service_status a 
JOIN testsuite.uris_long b ON a.gid = b.gid
ORDER BY entity,uri,task


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
		    WHEN service_status.exit_info = 'Curl got nothing from the server'::text THEN 'Empty response'::text
		    WHEN service_status.exit_info = 'An error occurred during the SSL/TLS handshake'::text THEN 'SSL error'::text
                    WHEN service_status.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
                    WHEN service_status.exit_info = 'Invalid HTTP status code 0'::text THEN 'Status code 0'::text
                    WHEN service_status.exit_info = 'Failure in receiving network data'::text THEN 'Network error'::text
                    WHEN service_status.exit_info = 'Failed to connect to host'::text THEN 'Cannot connect to host'::text
                    WHEN service_status.exit_info = 'Peer certificate cannot be authenticated with known CA certificates'::text THEN 'Certificates error'::text
                    WHEN service_status.exit_info ~~ 'Success with http code 200 after redir%'::text THEN '200 after 301/302 redirect'::text
                    WHEN service_status.exit_info = 'Invalid HTTP status code 301 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN service_status.exit_info = 'Invalid HTTP status code 302 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN service_status.exit_info ~~ 'Invalid HTTP status code%'::text AND service_status.exit_info <> 'Invalid HTTP status code 301 after redir'::text AND service_status.exit_info <> 'Invalid HTTP status code 302 after redir'::text THEN "right"(service_status.exit_info, 3)
                    ELSE service_status.exit_info
                END AS status_code,
            count(*) AS count,
            avg(service_status.task_duration) AS ping_average
           FROM testsuite.service_status
          WHERE service_status.task::text = 'url_status_codes'::text
          GROUP BY (
                CASE
		    WHEN service_status.exit_info = 'Curl got nothing from the server'::text THEN 'Empty response'::text
		    WHEN service_status.exit_info = 'An error occurred during the SSL/TLS handshake'::text THEN 'SSL error'::text
                    WHEN service_status.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
                    WHEN service_status.exit_info = 'Invalid HTTP status code 0'::text THEN 'Status code 0'::text
                    WHEN service_status.exit_info = 'Failure in receiving network data'::text THEN 'Network error'::text
                    WHEN service_status.exit_info = 'Failed to connect to host'::text THEN 'Cannot connect to host'::text
                    WHEN service_status.exit_info = 'Peer certificate cannot be authenticated with known CA certificates'::text THEN 'Certificates error'::text
                    WHEN service_status.exit_info ~~ 'Success with http code 200 after redir%'::text THEN '200 after 301/302 redirect'::text
                    WHEN service_status.exit_info = 'Invalid HTTP status code 301 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN service_status.exit_info = 'Invalid HTTP status code 302 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN service_status.exit_info ~~ 'Invalid HTTP status code%'::text AND service_status.exit_info <> 'Invalid HTTP status code 301 after redir'::text AND service_status.exit_info <> 'Invalid HTTP status code 302 after redir'::text THEN "right"(service_status.exit_info, 3)
                    ELSE service_status.exit_info
                END)
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.status_code,
                CASE a.status_code
		    WHEN 'Empty response'::text THEN 'Empty response'::text
		    WHEN 'SSL error'::text THEN 'SSL error'::text
                    WHEN '000'::text THEN 'Timeout'::text
                    WHEN 'URL status code check failed on a 20 secs timeout error'::text THEN 'Timeout'::text
                    WHEN '200'::text THEN 'OK'::text
                    WHEN '200 after 301/302 redirect'::text THEN 'OK after redirect'::text
                    WHEN '201'::text THEN 'Created'::text
                    WHEN '202'::text THEN 'Accepted'::text
                    WHEN '204'::text THEN 'No Content'::text
                    WHEN '301'::text THEN 'Moved Permanently'::text
                    WHEN '302'::text THEN 'Found'::text
                    WHEN 'Error HTTP status code after redirect'::text THEN 'Error after redirect'::text
                    WHEN '400'::text THEN 'Bad Request'::text
                    WHEN '401'::text THEN 'Unauthorized'::text
                    WHEN '403'::text THEN 'Forbidden'::text
                    WHEN '404'::text THEN 'Not Found'::text
                    WHEN '500'::text THEN 'Internal Server Error'::text
                    WHEN '502'::text THEN 'Bad Gateway'::text
                    WHEN '503'::text THEN 'Service Unavailable'::text
                    WHEN '504'::text THEN 'Gateway Timeout'::text
                    WHEN '499'::text THEN 'Client Closed Request'::text
                    WHEN 'Error resolving the URL host name'::text THEN 'Hostname unkwown'::text
                    WHEN 'Network error'::text THEN 'Network error'::text
                    WHEN 'Cannot connect to host'::text THEN 'Cannot connect to host'::text
                    WHEN 'Certificates error'::text THEN 'Certificates error'::text
                    WHEN 'Status code 0'::text THEN 'To be investigated'::text
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
  ORDER BY count DESC;

-- Count the URLs by they http status code and group also by organization
-- View: stats_and_metrics._03_group_by_http_status_code_and_entity

-- DROP VIEW stats_and_metrics._03_group_by_http_status_code_and_entity;

CREATE OR REPLACE VIEW stats_and_metrics._03_group_by_http_status_code_and_entity
 AS
 WITH a AS (
         SELECT
                CASE
				    WHEN b.exit_info = 'Curl got nothing from the server'::text THEN 'Empty response'::text
				    WHEN b.exit_info = 'An error occurred during the SSL/TLS handshake'::text THEN 'SSL error'::text
                    WHEN b.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
                    WHEN b.exit_info = 'Invalid HTTP status code 0'::text THEN 'Status code 0'::text
                    WHEN b.exit_info = 'Failure in receiving network data'::text THEN 'Network error'::text
                    WHEN b.exit_info = 'Failed to connect to host'::text THEN 'Cannot connect to host'::text
                    WHEN b.exit_info = 'Peer certificate cannot be authenticated with known CA certificates'::text THEN 'Certificates error'::text
                    WHEN b.exit_info ~~ 'Success with http code 200 after redir%'::text THEN '200 after 301/302 redirect'::text
                    WHEN b.exit_info = 'Invalid HTTP status code 301 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN b.exit_info = 'Invalid HTTP status code 302 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN b.exit_info ~~ 'Invalid HTTP status code%'::text AND b.exit_info <> 'Invalid HTTP status code 301 after redir'::text AND b.exit_info <> 'Invalid HTTP status code 302 after redir'::text THEN "right"(b.exit_info, 3)
                    ELSE b.exit_info
                END AS status_code,
            c.entity,
            count(*) AS count,
            avg(b.task_duration) AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'url_status_codes'::text
          GROUP BY c.entity, (
                CASE
				    WHEN b.exit_info = 'Curl got nothing from the server'::text THEN 'Empty response'::text
				    WHEN b.exit_info = 'An error occurred during the SSL/TLS handshake'::text THEN 'SSL error'::text
                    WHEN b.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
                    WHEN b.exit_info = 'Invalid HTTP status code 0'::text THEN 'Status code 0'::text
                    WHEN b.exit_info = 'Failure in receiving network data'::text THEN 'Network error'::text
                    WHEN b.exit_info = 'Failed to connect to host'::text THEN 'Cannot connect to host'::text
                    WHEN b.exit_info = 'Peer certificate cannot be authenticated with known CA certificates'::text THEN 'Certificates error'::text
                    WHEN b.exit_info ~~ 'Success with http code 200 after redir%'::text THEN '200 after 301/302 redirect'::text
                    WHEN b.exit_info = 'Invalid HTTP status code 301 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN b.exit_info = 'Invalid HTTP status code 302 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN b.exit_info ~~ 'Invalid HTTP status code%'::text AND b.exit_info <> 'Invalid HTTP status code 301 after redir'::text AND b.exit_info <> 'Invalid HTTP status code 302 after redir'::text THEN "right"(b.exit_info, 3)
                    ELSE b.exit_info
                END)
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.entity,
            a.status_code,
                CASE a.status_code
				    WHEN 'Empty response'::text THEN 'Empty response'::text
				    WHEN 'SSL error'::text THEN 'SSL error'::text
                    WHEN '000'::text THEN 'Timeout'::text
                    WHEN 'URL status code check failed on a 20 secs timeout error'::text THEN 'Timeout'::text
                    WHEN '200'::text THEN 'OK'::text
                    WHEN '200 after 301/302 redirect'::text THEN 'OK after redirect'::text
                    WHEN '201'::text THEN 'Created'::text
                    WHEN '202'::text THEN 'Accepted'::text
                    WHEN '204'::text THEN 'No Content'::text
                    WHEN '301'::text THEN 'Moved Permanently'::text
                    WHEN '302'::text THEN 'Found'::text
                    WHEN 'Error HTTP status code after redirect'::text THEN 'Error after redirect'::text
                    WHEN '400'::text THEN 'Bad Request'::text
                    WHEN '401'::text THEN 'Unauthorized'::text
                    WHEN '403'::text THEN 'Forbidden'::text
                    WHEN '404'::text THEN 'Not Found'::text
                    WHEN '500'::text THEN 'Internal Server Error'::text
                    WHEN '502'::text THEN 'Bad Gateway'::text
                    WHEN '503'::text THEN 'Service Unavailable'::text
                    WHEN '504'::text THEN 'Gateway Timeout'::text
                    WHEN '499'::text THEN 'Client Closed Request'::text
                    WHEN 'Error resolving the URL host name'::text THEN 'Hostname unkwown'::text
                    WHEN 'Network error'::text THEN 'Network error'::text
                    WHEN 'Cannot connect to host'::text THEN 'Cannot connect to host'::text
                    WHEN 'Certificates error'::text THEN 'Certificates error'::text
                    WHEN 'Status code 0'::text THEN 'To be investigated'::text
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
  ORDER BY entity, count DESC;

ALTER TABLE stats_and_metrics._03_group_by_http_status_code_and_entity
    OWNER TO dgt;



-- Count the URLs by they http status code and group also by domain
CREATE OR REPLACE VIEW stats_and_metrics._04_group_by_http_status_code_and_domain
 AS
 WITH a AS (
         SELECT
                CASE
                    WHEN b.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
					WHEN b.exit_info = 'Invalid HTTP status code 0'::text THEN 'Status code 0'::text
					WHEN b.exit_info = 'Failure in receiving network data'::text THEN 'Network error'::text
					WHEN b.exit_info = 'Failed to connect to host'::text THEN 'Cannot connect to host'::text
					WHEN b.exit_info = 'Peer certificate cannot be authenticated with known CA certificates'::text THEN 'Certificates error'::text
					WHEN b.exit_info ~~ 'Success with http code 200 after redir%'::text THEN '200 after 301/302 redirect'::text
					WHEN b.exit_info = 'Invalid HTTP status code 301 after redir'::text THEN 'Error HTTP status code after redirect'::text
				    WHEN b.exit_info = 'Invalid HTTP status code 302 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN 
					b.exit_info ~~ 'Invalid HTTP status code%'::text 
					AND
					b.exit_info != 'Invalid HTTP status code 301 after redir'::text
					AND
					b.exit_info != 'Invalid HTTP status code 302 after redir'::text
					THEN "right"(b.exit_info, 3)
                    ELSE b.exit_info
                END AS status_code,
            lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text)) AS uri_domain,
            count(*) AS count,
			avg(b.task_duration) AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'url_status_codes'::text
          GROUP BY (lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text))), (
                CASE
                    WHEN b.exit_info ~~ 'http_status_code: 200%'::text THEN '200'::text
					WHEN b.exit_info = 'Invalid HTTP status code 0'::text THEN 'Status code 0'::text
					WHEN b.exit_info = 'Failure in receiving network data'::text THEN 'Network error'::text
					WHEN b.exit_info = 'Failed to connect to host'::text THEN 'Cannot connect to host'::text
					WHEN b.exit_info = 'Peer certificate cannot be authenticated with known CA certificates'::text THEN 'Certificates error'::text
					WHEN b.exit_info ~~ 'Success with http code 200 after redir%'::text THEN '200 after 301/302 redirect'::text
					WHEN b.exit_info = 'Invalid HTTP status code 301 after redir'::text THEN 'Error HTTP status code after redirect'::text
				    WHEN b.exit_info = 'Invalid HTTP status code 302 after redir'::text THEN 'Error HTTP status code after redirect'::text
                    WHEN 
					b.exit_info ~~ 'Invalid HTTP status code%'::text 
					AND
					b.exit_info != 'Invalid HTTP status code 301 after redir'::text
					AND
					b.exit_info != 'Invalid HTTP status code 302 after redir'::text
					THEN "right"(b.exit_info, 3)
                    ELSE b.exit_info
                END)
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.uri_domain,
            a.status_code,
                CASE a.status_code
                    WHEN '000'::text THEN 'Timeout'::text
					WHEN 'URL status code check failed on a 20 secs timeout error'::text THEN 'Timeout'::text
                    WHEN '200'::text THEN 'OK'::text
					WHEN '200 after 301/302 redirect'::text THEN 'OK after redirect'::text
                    WHEN '201'::text THEN 'Created'::text
                    WHEN '202'::text THEN 'Accepted'::text
                    WHEN '204'::text THEN 'No Content'::text
                    WHEN '301'::text THEN 'Moved Permanently'::text
                    WHEN '302'::text THEN 'Found'::text
					WHEN 'Error HTTP status code after redirect'::text THEN 'Error after redirect'::text
                    WHEN '400'::text THEN 'Bad Request'::text
                    WHEN '401'::text THEN 'Unauthorized'::text
                    WHEN '403'::text THEN 'Forbidden'::text
                    WHEN '404'::text THEN 'Not Found'::text
                    WHEN '500'::text THEN 'Internal Server Error'::text
                    WHEN '502'::text THEN 'Bad Gateway'::text
                    WHEN '503'::text THEN 'Service Unavailable'::text
                    WHEN '504'::text THEN 'Gateway Timeout'::text
                    WHEN '499'::text THEN 'Client Closed Request'::text
					WHEN 'Error resolving the URL host name'::text THEN 'Hostname unkwown'::text
					WHEN 'Network error'::text THEN 'Network error'::text
					WHEN 'Cannot connect to host'::text THEN 'Cannot connect to host'::text
					WHEN 'Certificates error'::text THEN 'Certificates error'::text
					WHEN 'Status code 0'::text THEN 'To be investigated'::text
                    ELSE ''::text
                END AS status_code_definition,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT gid,
    uri_domain,
    status_code,
    status_code_definition,
    count,
    ping_average
   FROM temp
  ORDER BY uri_domain, count DESC;


-- Count the URLs by they WMS and WFS Capabilities document validity 
CREATE OR REPLACE VIEW stats_and_metrics._05_group_by_wms_capabilities_validity_global
 AS
 WITH a AS (
         SELECT
			service_status.exit_info AS status_code,
			service_status.exit_status,
            count(*) AS count,
			avg(service_status.task_duration) AS ping_average
          FROM testsuite.service_status
          WHERE service_status.task::text = 'wms_capabilities'::text
          GROUP BY service_status.exit_info, service_status.exit_status 
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.status_code,
            a.exit_status AS definition,
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
  ORDER BY count desc;

CREATE OR REPLACE VIEW stats_and_metrics._06_group_by_wfs_capabilities_validity_global
 AS
 WITH a AS (
         SELECT
			service_status.exit_info AS status_code,
			service_status.exit_status,
            count(*) AS count,
			avg(service_status.task_duration) AS ping_average
          FROM testsuite.service_status
          WHERE service_status.task::text = 'wfs_capabilities'::text
          GROUP BY service_status.exit_info, service_status.exit_status 
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.status_code,
            a.exit_status AS definition,
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
  ORDER BY count desc;


-- Count the URLs by they WMS/WFS Capabilities XML document validity and group also by organization
CREATE OR REPLACE VIEW stats_and_metrics._07_group_by_wms_capabilities_validity_and_entity
 AS
 WITH a AS (
         SELECT
			b.exit_info AS status_code,
			b.exit_status,
			c.entity,
            count(*) AS count,
			avg(b.task_duration) AS ping_average
          FROM testsuite.service_status b
		  JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wms_capabilities'::text
          GROUP BY c.entity, b.exit_info, b.exit_status 
        ), temp AS (
         SELECT row_number() OVER () AS gid,
		    a.entity,
            a.status_code,
            a.exit_status AS definition,
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
  ORDER BY entity, count desc;

CREATE OR REPLACE VIEW stats_and_metrics._08_group_by_wfs_capabilities_validity_and_entity
 AS
 WITH a AS (
         SELECT
			b.exit_info AS status_code,
			b.exit_status,
			c.entity,
            count(*) AS count,
			avg(b.task_duration) AS ping_average
          FROM testsuite.service_status b
		  JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wfs_capabilities'::text
          GROUP BY c.entity, b.exit_info, b.exit_status 
        ), temp AS (
         SELECT row_number() OVER () AS gid,
		    a.entity,
            a.status_code,
            a.exit_status AS definition,
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
  ORDER BY entity, count desc;


-- Count the URLs by they WMS/WFS Capabilities XML document validity and group also by domain
CREATE OR REPLACE VIEW stats_and_metrics._09_group_by_wms_capabilities_validity_and_domain
 AS
 WITH a AS (
         SELECT b.exit_info AS status_code,
            b.exit_status,
            lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text)) AS uri_domain,
            count(*) AS count,
            avg(b.task_duration) AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wms_capabilities'::text
          GROUP BY (lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text))), b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.uri_domain,
            a.status_code,
            a.exit_status AS definition,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT gid,
    uri_domain,
    status_code,
    definition,
    count,
    ping_average
   FROM temp
  ORDER BY uri_domain, count DESC;

CREATE OR REPLACE VIEW stats_and_metrics._10_group_by_wfs_capabilities_validity_and_domain
 AS
 WITH a AS (
         SELECT b.exit_info AS status_code,
            b.exit_status,
            lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text)) AS uri_domain,
            count(*) AS count,
            avg(b.task_duration) AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wfs_capabilities'::text
          GROUP BY (lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text))), b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.uri_domain,
            a.status_code,
            a.exit_status AS definition,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT gid,
    uri_domain,
    status_code,
    definition,
    count,
    ping_average
   FROM temp
  ORDER BY uri_domain, count DESC;


-- Count the URLs by they WMS and WFS gdal_info/ogr_info response validity 
CREATE OR REPLACE VIEW stats_and_metrics._11_group_by_wms_gdal_info_validity_global
 AS
 WITH a AS (
         SELECT service_status.exit_info AS status_code,
            service_status.exit_status,
            count(*) AS count,
            avg(service_status.task_duration) AS ping_average
           FROM testsuite.service_status
          WHERE service_status.task::text = 'wms_gdal_info'::text
          GROUP BY service_status.exit_info, service_status.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.status_code,
            a.exit_status AS definition,
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
  ORDER BY count DESC;

CREATE OR REPLACE VIEW stats_and_metrics._12_group_by_wfs_ogr_info_validity_global
 AS
 WITH a AS (
         SELECT 
                CASE
                    WHEN service_status.exit_info = 'valid WFS OGR info response (version 1.0.0)'::text THEN 'valid WFS OGR info response (version 1.0.0)'::text
                    WHEN service_status.exit_info = 'valid WFS OGR info response (version 1.1.0)'::text THEN 'valid WFS OGR info response (version 1.1.0)'::text
                    WHEN service_status.exit_info = 'valid WFS OGR info response (version 2.0.0)'::text THEN 'valid WFS OGR info response (version 2.0.0)'::text
                    WHEN service_status.exit_info = 'Service exception or error'::text THEN 'Service exception or error'::text
                    WHEN service_status.exit_info ~~ 'Service exception or error (%'::text THEN 'Non fatal exception/error'::text
                    ELSE service_status.exit_info
                END AS status_code,		 		 
            service_status.exit_status,
            count(*) AS count,
            avg(service_status.task_duration) AS ping_average
           FROM testsuite.service_status
          WHERE service_status.task::text = 'wfs_ogr_info'::text
          GROUP BY 
                CASE
                    WHEN service_status.exit_info = 'valid WFS OGR info response (version 1.0.0)'::text THEN 'valid WFS OGR info response (version 1.0.0)'::text
                    WHEN service_status.exit_info = 'valid WFS OGR info response (version 1.1.0)'::text THEN 'valid WFS OGR info response (version 1.1.0)'::text
                    WHEN service_status.exit_info = 'valid WFS OGR info response (version 2.0.0)'::text THEN 'valid WFS OGR info response (version 2.0.0)'::text
                    WHEN service_status.exit_info = 'Service exception or error'::text THEN 'Service exception or error'::text
                    WHEN service_status.exit_info ~~ 'Service exception or error (%'::text THEN 'Non fatal exception/error'::text
                    ELSE service_status.exit_info
                END, 
		  service_status.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.status_code,
            a.exit_status AS definition,
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
  ORDER BY count DESC;


-- Count the URLs by they WMS and WFS gdal_info/ogr_info response validity and group also by organization
CREATE OR REPLACE VIEW stats_and_metrics._13_group_by_wms_gdal_info_validity_and_entity
 AS
 WITH a AS (
         SELECT b.exit_info AS status_code,
            b.exit_status,
            c.entity,
            count(*) AS count,
            avg(b.task_duration) AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wms_gdal_info'::text
          GROUP BY c.entity, b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.entity,
            a.status_code,
            a.exit_status AS definition,
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
  ORDER BY entity, count DESC;
  
CREATE OR REPLACE VIEW stats_and_metrics._14_group_by_wfs_ogr_info_validity_and_entity
 AS
 WITH a AS (
         SELECT b.exit_info AS status_code,
            b.exit_status,
            c.entity,
            count(*) AS count,
            avg(b.task_duration) AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wfs_ogr_info'::text
          GROUP BY c.entity, b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.entity,
            a.status_code,
            a.exit_status AS definition,
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
  ORDER BY entity, count DESC;


-- Count the URLs by they WMS and WFS gdal_info/ogr_info response validity and group also by domain
CREATE OR REPLACE VIEW stats_and_metrics._15_group_by_wms_gdal_info_validity_and_domain
 AS
 WITH a AS (
         SELECT b.exit_info AS status_code,
            b.exit_status,
            lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text)) AS uri_domain,
            count(*) AS count,
            avg(b.task_duration) AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wms_gdal_info'::text
          GROUP BY (lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text))), b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.uri_domain,
            a.status_code,
            a.exit_status AS definition,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT gid,
    uri_domain,
    status_code,
    definition,
    count,
    ping_average
   FROM temp
  ORDER BY uri_domain, count DESC;

CREATE OR REPLACE VIEW stats_and_metrics._16_group_by_wfs_ogr_info_validity_and_domain
 AS
 WITH a AS (
         SELECT b.exit_info AS status_code,
            b.exit_status,
            lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text)) AS uri_domain,
            count(*) AS count,
            avg(b.task_duration) AS ping_average
           FROM testsuite.service_status b
             JOIN testsuite.uris_long c ON b.gid = c.gid
          WHERE b.task::text = 'wfs_ogr_info'::text
          GROUP BY (lower(regexp_replace(regexp_replace(c.uri_original, '^https?://'::text, ''::text), '(:[0-9]+)?/.*$'::text, ''::text))), b.exit_info, b.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            a.uri_domain,
            a.status_code,
            a.exit_status AS definition,
            a.count,
            a.ping_average
           FROM a
        )
 SELECT gid,
    uri_domain,
    status_code,
    definition,
    count,
    ping_average
   FROM temp
  ORDER BY uri_domain, count DESC;
