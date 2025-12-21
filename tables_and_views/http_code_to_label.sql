-- ============================================================
-- FUNCTION: testsuite.labels()
-- PURPOSE : Provide a lookup table mapping exit/status codes to
--           human-readable definitions.
-- RETURNS : TABLE (code TEXT, definition TEXT)
-- NOTES   :
--   - Used for interpreting exit codes or messages from monitoring tasks.
--   - Contains both HTTP status codes and custom labels.
-- ============================================================

CREATE OR REPLACE FUNCTION testsuite.labels()
RETURNS TABLE (
    code        TEXT,
    definition  TEXT
)
LANGUAGE sql
IMMUTABLE
AS $$
    VALUES
        -- General / Custom statuses
        ('Empty response',                              'Empty response'),
        ('SSL error',                                   'SSL error'),
        ('000',                                         'Timeout'),
        ('task execution times out after 20 secs',      'Timeout'),
        ('URL status code check failed on a 20 secs timeout error', 'Timeout'),

        -- Successful / Redirect HTTP statuses
        ('200',                                         'OK'),
        ('200 after 301/302 redirect',                  'OK after redirect'),
        ('201',                                         'Created'),
        ('202',                                         'Accepted'),
        ('204',                                         'No Content'),
        ('301',                                         'Moved Permanently'),
        ('302',                                         'Found'),
        ('Error HTTP status code after redirect',       'Error after redirect'),

        -- Client error HTTP statuses
        ('400',                                         'Bad Request'),
        ('401',                                         'Unauthorized'),
        ('403',                                         'Forbidden'),
        ('404',                                         'Not Found'),

        -- Server error HTTP statuses
        ('500',                                         'Internal Server Error'),
        ('502',                                         'Bad Gateway'),
        ('503',                                         'Service Unavailable'),
        ('504',                                         'Gateway Timeout'),

        -- Miscellaneous errors
        ('499',                                         'Client Closed Request'),
        ('Error resolving the URL host name',           'Hostname unknown'),
        ('Network error',                               'Network error'),
        ('Cannot connect to host',                      'Cannot connect to host'),
        ('Certificates error',                          'Certificates error'),
        ('Status code 0',                               'To be investigated');
$$;
