% @CMD@(1) Version 1.0 | List Registered Entities

NAME
====

**@CMD@** — List Registered Entities

SYNOPSIS
========

| **@CMD@** ?\[**Entity Definition Pattern**]?

DESCRIPTION
===========

Without arguments the command prints a table showing the entities registered in the database. The table shows

 1. The primary key of the entity
 2. The entity definition
 3. The number of services that belong to an entity

by default entities are listed ordered by number of resource records that belong to an entity

Options
-------

The command takes an optional argument that allows for selective searches in the database. For example

| @CMD@ "Direç%"

lists the entities whose definition begins with the pattern passed as argument

-alpha

:   List records in alphabetical order

EXAMPLES
========

| snig [3]> LE "Inst%" -alpha

from the CLI client outputs

```
+------------------------------------------------------------------------------+
|                            [108] List of Entities                            |
+-----+--------------------------------------------------------------+---------+
| Eid | Description                                                  | Records |
+-----+--------------------------------------------------------------+---------+
| 18  | Instituto da Conservação da Natureza e das Florestas, I.P.   | 229     |
| 37  | Instituto da Mobilidade e dos Transportes, I.P.              | 1       |
| 20  | Instituto de Financiamento de Agricultura e Pescas, I.P.     | 5       |
| 32  | Instituto Hidrográfico                                       | 44      |
| 9   | Instituto Nacional de Estatística, I.P.                      | 36      |
| 14  | Instituto Português do Mar e da Atmosfera, I.P. (IPMA, I.P.) | 119     |
+-----+--------------------------------------------------------------+---------+
```

BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@
