% @CMD@(snig) Version 1.0 | Print Current Worker Threads 

NAME
====

**@CMD@** — Display report of the current application worker threads state

SYNOPSIS
========

| **@CMD@** 

DESCRIPTION
===========

The monitor keeps a pool of worker threads for tasks to be executed. Threads
are created on demand up to the limit imposed be the configuration parameter
*max_workers_number* and are served to the **job_controller**. Threads execute
a maximum **max_job_executed** and can stay idle **max_worker_thread_idle**
seconds and then are release by the *release_idle_threads* chore

BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@

