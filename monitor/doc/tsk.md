% @CMD@(snig) Version 1.0 | Print Service Task Results

NAME
====

**@CMD@** — Print Service Task Results

SYNOPSIS
========

| **@CMD@** \[**gid**]

DESCRIPTION
===========

@CMD@ prints a table with the task results carried out on the service having **gid** as primary key. The table
colums are

 1. A description of the task
 2. The task final status. Possible values are 'ok','error' and 'warning'
 3. Info: informations concerning the status. Generally meaningful for 'error' and 'warning' exit status
 4. Timestamp: date and time of the task execution

```
snig [3]> @CMD@ 4
+------------------------------------------------------------------------------------------------------------------+
|                                [118] Plano de Pormenor da Zona Industrial de Vagos                               |
+------------------------------+--------+----------------------------------------------------+---------------------+
| Task                         | Status | Info                                               | Timestamp           |
+------------------------------+--------+----------------------------------------------------+---------------------+
| Record Data Congruence Check | ok     | Record data congruence tested                      | 2024-11-12 06:00:05 |
| Check URL Status Codes       | ok     | http_status_code: 200 ping_time: 7.453             | 2024-11-12 06:00:13 |
| WMS Capabilities             | ok     | valid WMS Capabilities XML document version 1.3.0  | 2024-11-12 06:00:15 |
| WMS GDAL info Capabilities   | error  | WMS GDAL info response failed on a 20 secs timeout | 2024-11-12 06:00:15 |
+------------------------------+--------+----------------------------------------------------+---------------------+
```


BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@
