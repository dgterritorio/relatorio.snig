% @CMD@(snig) Version 1.0 | Print Service Task Results

NAME
====

**@CMD@** — Print Service Task Results

SYNOPSIS
========

| **@CMD@** \[**gid1**] \[**gid2**] .... \[**description**] 

DESCRIPTION
===========

@CMD@ prints a table with the task results carried out on the services specified as arguments either with their
**gid** (Primary key) or description pattern. The column shown in the table are

 1. A description of the task
 2. The task final status. Possible values are 'ok','error' and 'warning'
 3. Info: informations concerning the status. Generally meaningful for 'error' and 'warning' exit status
 4. Timestamp: date and time of the task execution

EXAMPLES
========

```
snig [3]> taskres 194423 194425
+---------------------------------------------------------------------------------------------------------------------------+
|                                     [118] Campanha Geofísica TAGUSDELTA 2013 (194423)                                     |
+------------------------------+------------+---------------------------------------------------------+---------------------+
| Task                         | Status     | Info                                                    | Timestamp           |
+------------------------------+------------+---------------------------------------------------------+---------------------+
| Record Data Congruence Check |     ok     | Service Data congruence passed                          | 2025-10-27 23:20:02 |
| Check URL Status Codes       |  warning   | Success with http code 200 after redir (301) was issued | 2025-10-27 23:20:03 |
+------------------------------+------------+---------------------------------------------------------+---------------------+

+------------------------------------------------------------------------------------------------------------+
|                                   [118] Campanha Crustáceos 2009 (194425)                                  |
+------------------------------+------------+------------------------------------------+---------------------+
| Task                         | Status     | Info                                     | Timestamp           |
+------------------------------+------------+------------------------------------------+---------------------+
| Record Data Congruence Check |     ok     | Service Data congruence passed           | 2025-10-27 23:20:02 |
| Check URL Status Codes       |   error    | Invalid HTTP status code 301 after redir | 2025-10-27 23:20:03 |
+------------------------------+------------+------------------------------------------+---------------------+

snig [4]> @CMD@ "Risc%"
+---------------------------------------------------------------------------------------------------------------------------+
|                                        [118] Risco de Ruptura de Barragens (232602)                                       |
+------------------------------+------------+---------------------------------------------------------+---------------------+
| Task                         | Status     | Info                                                    | Timestamp           |
+------------------------------+------------+---------------------------------------------------------+---------------------+
| Record Data Congruence Check |     ok     | Service Data congruence passed                          | 2025-12-11 12:01:00 |
| Check URL Status Codes       |   error    | URL status code check failed on a 20 secs timeout error | 2025-12-11 12:01:20 |
+------------------------------+------------+---------------------------------------------------------+---------------------+

+---------------------------------------------------------------------------------------------------------------------------+
|                                          [118] Risco de Incêndios Rurais (232624)                                         |
+------------------------------+------------+---------------------------------------------------------+---------------------+
| Task                         | Status     | Info                                                    | Timestamp           |
+------------------------------+------------+---------------------------------------------------------+---------------------+
| Record Data Congruence Check |     ok     | Service Data congruence passed                          | 2025-11-06 16:49:49 |
| Check URL Status Codes       |   error    | URL status code check failed on a 20 secs timeout error | 2025-11-06 16:50:10 |
+------------------------------+------------+---------------------------------------------------------+---------------------+

+---------------------------------------------------------------------------------------------------------------------------+
|                                           [118] Risco de Ondas de Calor (234883)                                          |
+------------------------------+------------+---------------------------------------------------------+---------------------+
| Task                         | Status     | Info                                                    | Timestamp           |
+------------------------------+------------+---------------------------------------------------------+---------------------+
| Record Data Congruence Check |     ok     | Service Data congruence passed                          | 2025-10-27 16:25:02 |
| Check URL Status Codes       |   error    | URL status code check failed on a 20 secs timeout error | 2025-10-27 16:25:22 |
+------------------------------+------------+---------------------------------------------------------+---------------------+
```


BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@
