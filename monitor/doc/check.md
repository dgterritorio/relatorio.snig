% @CMD@(1) Version 1.0 | Launch Job Sequences

NAME
====

**@CMD@** — Launch Job Sequences

SYNOPSIS
========

| **@CMD@** ?\[**entity pattern**\]? ?\[**gid**]? ?\[**gid='service record gid'**] ?\[**eid='entity id'**]?

DESCRIPTION
===========

Launch Job Sequences using different patterns of selection in the database. The command accepts multiple
arguments among the accepted patterns. 

EXAMPLES
========

the following command

**@CMD@** 100 101 102 "Direção Regional do Planeamento e Fundos Estruturais" eid=28

Launches 3 job sequences

 1. The first sequence comprises 3 Jobs for the services having gids 100 101 102
 2. The second sequence comprises of the jobs for the records belonging to\
    the entity 'Direção Regional do Planeamento e Fundos Estruturais'
 3. The third job is a sequence comprising the jobs for the 5 service records\
    belonging to the entity "Direção-Geral da Agricultura e Desenvolvimento Rural"

BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@
