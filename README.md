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
* tcl8.6
* tcllib
* tcl-syslog
* tcl-unix-sockets
* tcl8.6-tdbcpostgres
* tcl-thread
* tcl-tls

## Web interface dependencies

* apache2
* libapache2-mod-rivet (enable either the prefork or worker mpm modules)

## System setup:

* Install the dependencies: 

apt-get install git gdal-bin jq csvtool xmlstarlet csvkit parallel libxml2-utils postgresql-16-postgis-3-scripts postgis

* User creation.

If you want you may create a user to install the monitor code. Any non privileged user would work. In this documentation we assume the installation to be made by user snig having /home/snig as root 

* Cloning the repository. (In order to clone the repository the 'git' utility must be installed)

```
# git https://github.com/dgterritorio/relatorio.snig.git 
```

this command will create a relatorio.snig directory with the monitor code. You can change the name of the directory by passing its path as final argument. The full path to this directory will be referenced as <snig-monitor-root> across this document

```
# git https://github.com/dgterritorio/relatorio.snig.git <snig-monitor-root>
```

* Create the snig monitor configuration. The file <snig-monitor-root>/monitor/ngis_monitor_conf.tcl must be created from <snig-monitor-root>/monitor/ngis_monitor_conf.template.tcl and modified with the appropriate parameters values.
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
Type=simple
User=snig
Group=snig
ExecStart=/usr/bin/tclsh8.6 <snig-monitor-root>/monitor/run_server.tcl
```
Replace the path to run_server with the actual path to the code. You may start it by typing `systemctl start snig-monitor`. The service will start anyway at boot time

* Service Installation

## CLI Usage:

## Anatomy of a script implementing a control task

## Create a crontab entry for the monitor
From the shell of the user running the monitor type

```
crontab -e
```
and write the following line in it
```
0 6 * * * /usr/bin/tclsh8.6 <snit-monitor-root>/home/snig/relatorio.snig/monitor/utils/general_test.tcl
```
this line will run the tests on all the resources every day at 6 AM. To customize this schedule refer to the cron manual page
