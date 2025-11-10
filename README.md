# SNIG: Services Quality Report

A collection of scripts to harvest and (health) check the services published at https://snigreport.dgterritorio.gov.pt/

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
* Tclx
* libjs-jquery
* pandoc
* php*-cli
* php*-pgsql
* php*-gd
* composer (a dependency manager for PHP)
* zip

## Web interface dependencies

* apache2
* libapache2-mod-rivet (enable either the prefork or worker mpm modules)

## System setup:

* Install the dependencies: 

apt-get install git gdal-bin jq csvtool xmlstarlet csvkit parallel libxml2-utils postgresql-16-postgis-3-scripts postgis pandoc composer php8.3-cli php8.3-pgsql php8.3-gd zip

* System user creation.

If you want, you may create a system user to install the monitor code. Any non privileged user would work. In this documentation we assume the installation to be made by user snig having ```/home/snig``` as root 

* Cloning the repository. (In order to clone the repository the 'git' utility must be installed)

```
# git https://github.com/dgterritorio/relatorio.snig.git 
```

this command will create a relatorio.snig directory with the monitor code. You can change the name of the directory by passing its path as final argument. The full path to this directory will be referenced as <snig-monitor-root> across this document

```
# git https://github.com/dgterritorio/relatorio.snig.git <snig-monitor-root>
```

* Setup the Postgresql database, user, tables, etc.

A PostgreSQL user is needed for the monitor, the scripts that harvest URLs from https://snig.dgterritorio.gov.pt/ and to run the queries that define the tables (or views) with metrics and statistics extracted from the monitor tests results. For example

```
# su postgres
# psql
# CREATE ROLE dgt LOGIN PASSWORD '***';
# CREATE DATABASE snig TEMPLATE template0 OWNER dgt;
```
The postgresql user only needs local (localhost) access to the database, but if monitor/stats tables must be accessible remotely then adjust accordingly PostgreSQL configuration files ```postgresql.conf``` and ```pg_hba.conf```.

Adjust the database configuration parameters in ```<snig-monitor-root>/standalone_scripts/connection_parameters.txt```
```
DB_NAME="snig"
USERNAME="dgt"
PASSWORD="***"
HOST="localhost"
```
Run the script that generates the encessary tables and views

```
# <snig-monitor-root>/standalone_scripts/create_tables_and_views.sh
```

* Create a crontab entry for the script that will do all the operations of harvesting URLs, importing, updating, etc.
```
crontab -e
```
and write the following line in it
```
0 18 * * 5 <snit-monitor-root>/standalone_scripts/00_harvest_import_and_update.sh
```
adjusting the frequency as desired (in the above example is "run at 6pm on Fridays).

* Create the snig monitor configuration. The file ```<snig-monitor-root>/monitor/ngis_monitor_conf.tcl``` must be created from ```<snig-monitor-root>/monitor/ngis_monitor_conf.template.tcl``` and modified with the appropriate parameters values.
```
  namespace eval ::ngis {

    variable HOST               "127.0.0.1"                ; # Postgresql database host
    variable USERNAME           "***"                      ; # Postgresql database user
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
* Create a snig-monitor service

Create file ```/etc/systemd/system/snig-monitor.service``` and write the following lines in it
```
[Unit]
Description=Snig Resources Monitor Server
After=network.target

[Service]
Type=simple
User=snig
Group=snig
ExecStart=/usr/bin/tclsh8.6 <snig-monitor-root>/monitor/run_server.tcl

[Install]
WantedBy=default.target
```
Replace the path to run_server with the actual path to the code.

* Service Installation

  Enable the service by typing (as root)

```
systemctl enable snig-monitor
```
* Start the service

```
systemctl start snig-monitor
```

The service will start anyway at boot time

* Enter the "standalone_scripts" folder and install two dependencies with PHP composer

```
composer require mpdf/mpdf:^8.0
composer require phpmailer/phpmailer
```

## CLI Usage:

Assuming your working directory is <snig-monitor-root> (e.g. /home/naturalgis/snig-monitor)
you can run the CLI client by typing

```
monitor/run_client.tcl
```
The client accepts commands from a prompt line that shown the number of commands entered during a
session. The CLI keeps an history of commands that can be navigated with the arrow-up and arrow-down
keys or searched using the Ctrl-R sequence and then by entering 

The CLI commands list is available with the command ```HELP``` (which has the ```?``` as an alias)

```
snig [3]> ?
CHECK     : Starts Monitoring Jobs
ENTITIES  : List Entities
EXIT      : Exit client
FORMAT    : Set/Query message format
HELP      : List CLI Commands
JOBLIST   : List Running Jobs
LSSERV    : List of service records for an Entity
NOOP      : Noop command as a keep-alive of socket connections
REGTASK   : List registered tasks
RUNSEQ    : Query Sequence Execution Status
SERVICE   : Query Service Data
SHUTDOWN  : Immediate Client and Server termination
STOP      : Stop Monitor Operations
TASKRES   : Display Task results
WHOS      : List Active Connections
ZZ        : Send custom messages to the server
```

Full informational pages are available as Unix-like manual pages. For example
```
snig [4]> HELP CHECK
```

Commands can be abbreviated as long as their non-ambigous. For example

```
snig [5]> W
```
is equivalent to `WHOS` but `S` is not accepted because there are 3 commands having
the same initial letter.

## CLI Commands Categories

The CLI commands fall in 4 categories 

 * Job management (`CHECK`, `STOP`, `JOBLIST`, `RUNSEQ`)
 * Protocol Control (`FORMAT`)
 * Service Records Database Information (`ENTITIES`, `LSSERV`, `SERVICE`, `TASKRES`)
 * Server Control (`WHOS`,`SHUTDOWN`)

### Job Management

 * `CHECK`: starts a job sequence for the purpose of checking a set of service records. The command
accepts a variable number of arguments with different forms. See the command man page by typing
 `HELP CHECK` from the CLI
 * `STOP`: stops all the job sequences. There is no implementation of session or job sequence ownership
therefore `STOP` sends a termination signal to all of them, regardless the session they were started from.
The stop signal does not perform a preemptive interruption of the running threads and in order to have a full
stop of the job sequences the tasks running have to orderly terminate
 * `JOBLIST`: displays a table of the running threads with the tasks names and their service record descriptions
 * `RUNSEQ`: prints a table of the current running job sequences

### Protocol Control

The server can respond to a CLI in a *human readable* (HR) format or with *JSON* messages. By default the server
responds with the *HR* format

 * `FORMAT`: without arguments returns the current protocol format. Otherwise accepts either `HR` or `JSON`

### Service Records Database

 * `ENTITIES`: list the entities of registered service records. The table shows for each entity the integer key, definition and number of records
 * `LSSERV`: displays a table of the service records belonging to an entity
 * `SERVICE`: prints information about a specific record (some information are truncated for readability, use the *JSON* format to have the full version of data)
 * `TASKRES`: prints results of tasks performed on a given resource record

### Server Control

 * `WHOS`: display a table with the current session connected to the server
 * `SHUTDOWN`: Interrupts current running jobs. It subsequently causes the monitor server and the client to exit (see `HELP SHUTDOWN` for more information)
 * `ZZ`: is a command meant for development only

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
