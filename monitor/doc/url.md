% @CMD@(snig) Version 1.0 | Display Service Data and Status

NAME
====

**@CMD@** — Display Service Data and Status

SYNOPSIS
========

| **@CMD@** ?\[**<gid service primary key>**]? ?\[**Service Description**]? ...

DESCRIPTION
===========

Command @CMD@ asks the SNIG server to search a service records having primary integer key **gid** or a given record description.
The command accepts multiple arguments in mixed forms

 1. An integer key value
 2. gid=<int> synonym of case 1
 3. A string that is searched in the service description column

EXAMPLES
========
```
snig[2]> @CMD@ 2032 4455 "Censo Nacional do Lobo-ibérico%"
```
Prints data for services having 2032 and 4455 as primary key or any service having a description beginning with
"Censo Nacional do Lobo-ibérico%"

Output example for service with primary key 4
```
snig [1]> @CMD@ 4
+-----------------------------------------------------------------------------------------------------------------------------------------+
|                                           [116] Plano de Pormenor da Zona Industrial de Vagos                                           |
+-------------+---------------------------------------------------------------------------------------------------------------------------+
| gid         | 4                                                                                                                         |
| uuid        | 00287f12-670c-4dde-8a38-e4f7a048c5bc                                                                                      |
| Description | Plano de Pormenor da Zona Industrial de Vagos                                                                             |
| URL         | http://servicos.dgterritorio.pt/sdisnitWMSPP6_0118_900_1/wmservice.aspx?service=WMS&version=1.3.0&request=GetCapabilities |
| Type        | WMS                                                                                                                       |
| Version     | 1.3.0                                                                                                                     |
+-------------+---------------------------------------------------------------------------------------------------------------------------+
```
BUGS
====

Please report bugs at: @BUG_REPORTS@

AUTHOR
======

@AUTHOR@
