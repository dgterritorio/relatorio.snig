% @CMD@(snig) Version 1.0 | List Service Records

NAME
====

**@CMD@** — List Service Records

SYNOPSIS
========

| **@CMD@**  ?\[**Entity Description Pattern**\] | \[**eid**]? 

DESCRIPTION
===========

Command **@CMD@** returns a list of services belonging to a given entity. The entity argument
can either be a definition string or an integer representing the entity id (eid)

EXAMPLES
========
```
snig [10]> lss 24
+--------------------------------------------------------------------------------------+
|                                 [122] Service Records                                |
+------+---------------------------------------+----------------------+------+---------+
| GID  | Description                           | Host                 | Type | Version |
+------+---------------------------------------+----------------------+------+---------+
| 1439 | Undefined description                 | wssig5.azores.gov.pt | WFS  | 1.1.0   |
| 1438 | Undefined description                 | wssig5.azores.gov.pt | WFS  | 2.0.0   |
| 321  | Hidrantes - Região Autónoma dos...... | wssig5.azores.gov.pt | WMS  | 1.3.0   |
| 243  | Estabelecimentos de......             | wssig5.azores.gov.pt | WFS  | 1.1.0   |
| 242  | Estabelecimentos de......             | wssig5.azores.gov.pt | WFS  | 2.0.0   |
| 2588 | Undefined description                 | wssig5.azores.gov.pt | WMS  | 1.3.0   |
+------+---------------------------------------+----------------------+------+---------+
```

BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@

