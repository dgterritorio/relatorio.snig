CREATE OR REPLACE FUNCTION testsuite.labels()
RETURNS TABLE (code text, definition text)
LANGUAGE sql
IMMUTABLE
AS $$
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
$$;

