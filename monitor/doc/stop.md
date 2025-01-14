% @CMD@(snig) Version 1.0 | Stop Operation Command

NAME
====

**@CMD@** — Stop current monitor operations

SYNOPSIS
========

| **@CMD@**

DESCRIPTION
===========

@CMD@ sends a STOP signal to current monitor operations. Job having running threads may
not stop immediately, since once a task has started it can only exit after its checks have been
performed or some timeout condition has occurred. Currently this command stops every operations,
including those that may have been stared by another connection and therefore it's for
management or testing purposes only

BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@
