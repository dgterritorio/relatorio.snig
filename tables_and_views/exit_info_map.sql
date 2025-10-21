CREATE OR REPLACE FUNCTION testsuite.exit_info_map(exit_info text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT CASE
    WHEN exit_info = 'Curl got nothing from the server' THEN 'Empty response'
    WHEN exit_info = 'An error occurred during the SSL/TLS handshake' THEN 'SSL error'
    WHEN exit_info LIKE 'http_status_code: 200%' THEN '200'
    WHEN exit_info = 'Invalid HTTP status code 0' THEN 'Status code 0'
    WHEN exit_info = 'Failure in receiving network data' THEN 'Network error'
    WHEN exit_info = 'Failed to connect to host' THEN 'Cannot connect to host'
    WHEN exit_info = 'Peer certificate cannot be authenticated with known CA certificates' THEN 'Certificates error'
    WHEN exit_info LIKE 'Success with http code 200 after redir%' THEN '200 after 301/302 redirect'
    WHEN exit_info IN ('Invalid HTTP status code 301 after redir',
                       'Invalid HTTP status code 302 after redir')
      THEN 'Error HTTP status code after redirect'
    WHEN exit_info LIKE 'Invalid HTTP status code%'
         AND exit_info NOT IN ('Invalid HTTP status code 301 after redir',
                               'Invalid HTTP status code 302 after redir')
      THEN COALESCE(NULLIF(SUBSTRING(exit_info FROM '(\d{3})$'), ''), exit_info)
    ELSE exit_info
  END;
$$;

