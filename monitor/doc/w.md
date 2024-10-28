% @CMD@(1) Version 1.0 | List Connected Sessions

NAME
====

**@CMD@** — List currently registered server sessions

SYNOPSIS
========

| **@CMD@** 

DESCRIPTION
===========

The server responds to this command showing a table of data regarding current registered connections. The table shows

 1. The connection login time
 2. The type of the connetion, either 'unix-socket' or 'TCP/IP"
 3. Number of commands executed through the connection
 4. Format of responses. Either "JSON" or "HR"
 6. Idle time after the last command was issued

EXAMPLES
========

```
snig [6]> w
+---------------------------------------------------------------------------------+
|                            [112] 2 Sessions Connected                           |
+---------------------+-------------+-----------------+--------+------------------+
| Login               | Socket      | Commands Exec.  | Format | Idle             |
+---------------------+-------------+-----------------+--------+------------------+
| 27-10-2024 17:12:15 | unix-socket | 5               | HR     | 41 mins, 57 secs |
| 27-10-2024 17:55:00 | TCP/IP      | 3               | HR     | 0 mins, 0 secs   |
+---------------------+-------------+-----------------+--------+------------------+
```

BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@

