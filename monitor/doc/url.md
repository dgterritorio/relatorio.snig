% @CMD@(1) Version 1.0 | Display Service Data and Status

NAME
====

**@CMD@** — Display Service Data and Status

SYNOPSIS
========

| **@CMD@** ?\[**<gid service primary key>**]? ?\[**Service Description**]? ...

DESCRIPTION
===========

Command @CMD@ asks the SNIG server to search a service records having primary integer key **gid** or a given record description.
The command accepts multiple arguments in mixed form

EXAMPLES
========

| snig[2]> @CMD@ 2032 4455 "Censo Nacional do Lobo-ibérico%"


BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@
