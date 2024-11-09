% @CMD@(1) Version 1.0 | Display Job List

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
snig [4]> c 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 eid=10
+--------------------------------------------------------------------------------+
|[002] OK                                                                        |
+--------------------------------------------------------------------------------+
|snig [5]> JL
```
+--------------------------------------------------------------------------------------------------------------------+
|                                                [114] 5 Job Executing                                               |
+------+-----------------------------------------------------------+----------+---------+------------------+---------+
| GID  | Description                                               | URL Type | Version | Status           | Running |
+------+-----------------------------------------------------------+----------+---------+------------------+---------+
| 14   | Plano de Pormenor do Parque Empresarial de São Brás de... | WMS      | 1.3.0   | wms_capabilities | 2 secs  |
| 15   | Carta da Reserva Ecológica Nacional - Tavira              | WMS      | 1.3.0   | wms_capabilities | 1 secs  |
| 3143 | Património cultural arqueológico                          | WMS      | 1.3.0   | url_status_codes | 18 secs |
| 4212 | Património cultural arqueológico                          | WFS      | 2.0.0   | url_status_codes | 10 secs |
| 4213 | Património cultural arqueológico                          | WFS      | 1.1.0   | url_status_codes | 10 secs |
+------+-----------------------------------------------------------+----------+---------+------------------+---------+
```

BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@
