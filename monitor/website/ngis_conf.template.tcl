#
# -- ./ngis_conf.tcl
#
#
#

package require ngis::readconf

namespace eval ::ngis::configuration {

# -- Section snig_server
#
	variable snig_server_dir          ".."                                     ;# SNIG Monitor Server Root Directory

# -- Section website
#
	variable cssprogressive           20241201                                 ;# CSS progressive number to force reloads
	variable development              "true"                                   ;# Flag to enable development site specific parts
	variable encoding                 "utf-8"                                  ;# Website default character encoding
	variable service_recs_limit       100                                      ;# Size of the default view of an entity service records
	variable website                  "http://snig.rivetweb.org:8080"          ;# Website Name
    variable template                 "forty"				                   ;# Default Template
    variable administrative_login     "dgt"                                    ;# Administrative login

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
	variable service_status           "testsuite.service_status"               ;# Service Status Records
	variable uris_table               "testsuite.uris_long"                    ;# URIs catalog table
	variable users_table              "testsuite.snig_users"                   ;# SNIG User Table

# -- Section network
#
	variable server_ip                "127.0.0.1"                              ;# SNIG Monitor Server
	variable server_port              4422                                     ;# SNIG Monitor Server Port

# -- Section jquery
#
	variable jquery_root              "http://ngis.rivetweb.org:8080"          ;# Root of the jQuery library
	variable jquery_uri               "jQuery/jquery.min.js"                   ;# jQuery file name
}
package provide ngis::configuration 2.1
