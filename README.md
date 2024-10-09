# SNIG: Services Quality Report

A collection of scripts to harvest and (health) check the services published at https://snig.dgterritorio.gov.pt/

# Requirements:
 Ubuntu 24.10 or Debian trixie (or later)

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
* libapache2-mod-rivet (enable either the prefork or worker mpm module)
* apache2
* tcl-syslog
* tcl-unix-sockets
* tcl8.6-tdbcpostgres
* tcl-thread
* tcl-tls

## System setup:

* Install the dependencies: 

apt-get install git gdal-bin jq csvtool xmlstarlet csvkit parallel libxml2-utils postgresql-16-postgis-3-scripts postgis

* Cloning the repository

* The file <snig-monitor-root>/monitor/ngis_monitor_conf.tcl must be edited and the appropriate parameters values must be modified.
```
  namespace eval ::ngis {

    variable HOST               "127.0.0.1"                ; # Postgresql database host
    variable USERNAME           "****                      ; # Postgresql database user
    variable PASSWORD           "***"                      ; # Postgresql database name
    variable DB_NAME            "***"
    variable TABLE_NAME         "testsuite.uris_long"
    variable ENTITY_TABLE_NAME  "testsuite.entities"
    variable SERVICE_STATUS     "testsuite.service_status"
    variable PORT               "5432"
    variable COLUMN_NAMES       "gid,uuid,uri,entity,description,uri_type,version"
    variable SERVICE_LOG        "testsuite.service_log"
    variable TIMEZONE           "Europe/Lisbon"
    variable data_root          [file join / tmp snig]

    variable max_workers_number 50                         ; # Max number of worker threads
    variable unix_socket_name   /tmp/ngis.socket
    variable rescheduling_delay 100
    variable curldir            ""

    variable tcpaddr            ""
    variable tcpport            ""
}

package provide ngis::conf 1.1
```

* Setup the Postgresql database

* Create a snig-monitor service

Create file /etc/systemd/system/snig-monitor.service and write the following lines in it
```
[Unit]
Description=Snig Resources Monitor Server
After=network.target

[Service]
ExecStart=/usr/bin/tclsh8.6 /home/snig/relatorio.snig/monitor/run_server.tcl
Type=simple
```
Replace the path to run_server with the actual path to the code. You may start it by typing `systemctl start snig-monitor`. The service will start anyway at boot time

* Service Installation

## CLI Usage:


