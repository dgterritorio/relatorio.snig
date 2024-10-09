# SNIG: Services Quality Report

A collection of scripts to harvest and (health) check the services published at https://snig.dgterritorio.gov.pt/

## Dependencies:

* git
* gdal-bin >= 3.7 (gdalinfo, ogrinfo, ogr2ogr, etc.)
* jq
* csvtool
* xmlstarlet
* csvkit
* xmllint
* parallel
* postgresql
* Tcl
* libapache2-mod-rivet (enable either mpm prefork or worker)
* apache2
* tcl-syslog
* tcl-unix-sockets
* tcl8.6-tdbcpostgres
* tcl-thread

## System setup:

* Install the dependencies: 

apt-get install git gdal-bin jq csvtool xmlstarlet csvkit parallel libxml2-utils postgresql-16-postgis-3-scripts postgis
