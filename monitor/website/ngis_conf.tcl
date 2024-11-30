#
# -- ./ngis_conf.tcl
#
#
# Configuration file regenerated 29-11-2024 23:59:09 
#

package require ngis::conf::generator
namespace eval ngis::conf {

# -- Section snig_server
#
	variable snig_server_dir          ".."                                     ;# SNIG Monitor Server Root Directory

# -- Section website
#
	variable cssprogressive           0                                        ;# CSS progressive number to force reloads
	variable development              "true"                                   ;# Flag to enable development site specific parts
	variable encoding                 "utf-8"                                  ;# Website default character encoding
	variable website                  "http://snig.rivetweb.org:8080"          ;# Website Name

# -- Section dbauth
#
	variable dbhost                   "snig.naturalgis.pt"                     ;# Backend database host
	variable dbname                   "snig"                                   ;# Backend database
	variable dbpasswd                 "W8a1kCUOx0mupUAF"                       ;# DB password
	variable dbport                   5432                                     ;# Backend database port
	variable dbuser                   "dgt"                                    ;# Backend database user

# -- Section database
#
	variable dbms_driver              "Tdbc Postgresql"                        ;# Database DIO Driver
	variable entities_table           "testsuite.entities"                     ;# Entities catalog table
	variable service_stautus          "testsuite.service_status"               ;# Service Status Records
	variable uris_table               "testsuite.uris_long"                    ;# URIs catalog table

# -- Section network
#
	variable server_ip                "127.0.0.1"                              ;# SNIG Monitor Server
	variable server_port              4422                                     ;# SNIG Monitor Server Port

# -- Section jquery
#
	variable ckeditor_root            "http://jquery.biol.unipr.it"            ;# Root of the ckeditor code
	variable fullcal_root             "http://jquery.biol.unipr.it"            ;# Root of FullCalendar code
	variable jqtimepicker             "http://jquery.biol.unipr.it/jquery-timepicker-1.3.5" ;# jQuery timepicker
	variable jquery_root              "http://jquery.biol.unipr.it"            ;# Root of the jQuery library

}
package provide ngis::configuration 1.1
