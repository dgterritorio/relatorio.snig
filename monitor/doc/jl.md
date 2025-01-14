% @CMD@(snig) Version 1.0 | Display Job List

NAME
====

**@CMD@** — Display table of running jobs

SYNOPSIS
========

| **@CMD@** 

DESCRIPTION
===========

Displays a table of currently running jobs. The table columns are

 1. GID: primary key of the service record
 2. Description
 3. URL Type: can be either WMS WFS or WCS
 4. Version: Protocol level version
 5. Task: task currently under execution
 6. Running: time elapsed since the job was created

EXAMPLES
========
```
snig [2]> check 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 eid=10
+--------------------------------------------------------------------------------+
|[102] OK                                                                        |
+--------------------------------------------------------------------------------+

snig [3]> runs
+-----------------------------------------------------------------------------------------------------+
|                                      [106] Job Sequences Status                                     |
+--------+--------------------------------------+--------------+----------------+------------+--------+
| Seq ID | Description                          | Running Jobs | Completed Jobs | Total Jobs | Status |
+--------+--------------------------------------+--------------+----------------+------------+--------+
| seq1   | Series of 14 records                 | 2            | 0              | 14         | queued |
| seq2   | Direção-Geral do Património Cultural | 3            | 0              | 10         | queued |
+--------+--------------------------------------+--------------+----------------+------------+--------+
| 5 running 0 idle threads                                                                            |
+-----------------------------------------------------------------------------------------------------+

snig [4]> joblist
+-------------------------------------------------------------------------------------------+
|                                   [114] 5 Job Executing                                   |
+------+----------------------------------+----------+---------+------------------+---------+
| GID  | Description                      | URL Type | Version | Task             | Running |
+------+----------------------------------+----------+---------+------------------+---------+
| 2    |                                  | WFS      | 2.0.0   | url_status_codes | 1 secs  |
| 3    |                                  | WFS      | 1.1.0   | url_status_codes | 1 secs  |
| 3327 |                                  | WFS      | 1.1.0   | url_status_codes | 1 secs  |
| 3326 |                                  | WFS      | 2.0.0   | url_status_codes | 1 secs  |
| 4213 | Património cultural arqueológico | WFS      | 1.1.0   | url_status_codes | 1 secs  |
+------+----------------------------------+----------+---------+------------------+---------+
```

BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@
