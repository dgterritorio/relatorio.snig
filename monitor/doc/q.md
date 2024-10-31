% @CMD@(1) Version 1.0 | Examine Job Sequence Status

NAME
====

**@CMD@** — Examine Job Sequence Status

SYNOPSIS
========

| **@CMD@** ?\[Sequence Pattern]?

DESCRIPTION
===========

The command returns a report of the current Job Sequences under execution by printing a report having this form
```
+----------------------------------------------------------------------------------------------------------------------------------------------+
|                                                          [106] Job Sequences Status                                                          |
+--------+------------------------------------------------------------------------------+--------------+----------------+------------+---------+
| Seq ID | Description                                                                  | Running Jobs | Completed Jobs | Total Jobs | Status  |
+--------+------------------------------------------------------------------------------+--------------+----------------+------------+---------+
| seq7   | Direção Regional de Organização e Administração Pública / Governo dos Açores | 5            | 2              | 19         | queued  |
| seq8   | Direção Regional do Planeamento e Fundos Estruturais                         | 0            | 7              | 11         | queued  |
| seq6   | Direção-Geral da Agricultura e Desenvolvimento Rural                         | 5            | 0              | 5          | pending |
+--------+------------------------------------------------------------------------------+--------------+----------------+------------+---------+
| 10 running 0 idle threads                                                                                                                    |
+----------------------------------------------------------------------------------------------------------------------------------------------+
```

The columns have the following meanings

 1. Seq ID: an internal reference to the job sequence. It can be used in future\
    version to allow operations on specific job sequences
 2. Description: The description of a job sequence varies accordingly to the method\
    it was generated from. For a job created specifying an entity ID or its definition\
    the defined description in the database is shown. For a job created out of a series of\
    service records the generic description "Series of ## records", where '##' is replaced\
    with the number of jobs
 3. Running Jobs: Number of jobs in the sequence to which a thread is currently assigned (and therefore\
    are performing their tasks)
 4. Completed Jobs: Number of jobs in a sequence that have terminated their tasks
 5. Total Jobs: Number of Jobs to be carried out
 6. Status: Can be "queued" or "pending". A queued sequence is still sitting in the job sequences\
    round-robin. When a Job finishes its thread is made available to new Job Sequences present\
    in the round-robin. When a job sequence has finished to schedule its jobs but some of them are still\
    running the sequence is placed in status "pending", meaning 'pending for termination'

A bottom row is printed showing the current status of the thread pool

BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@

