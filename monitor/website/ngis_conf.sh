
# -- Section database
#
dbms_driver="Tdbc Postgresql"	# Database DIO Driver
entities_table="testsuite.entities"	# Entities catalog table
service_stautus="testsuite.service_status"	# Service Status Records
uris_table="testsuite.uris_long"	# URIs catalog table

# -- Section dbauth
#
dbhost="snig.naturalgis.pt"	# Backend database host
dbname="snig"	# Backend database
dbpasswd="W8a1kCUOx0mupUAF"	# DB password
dbport="5432"	# Backend database port
dbuser="dgt"	# Backend database user

# -- Section jquery
#
ckeditor_root="http://jquery.biol.unipr.it"	# Root of the ckeditor code
fullcal_root="http://jquery.biol.unipr.it"	# Root of FullCalendar code
jqtimepicker="http://jquery.biol.unipr.it/jquery-timepicker-1.3.5"	# jQuery timepicker
jquery_root="http://ngis.rivetweb.org:8080"	# Root of the jQuery library
jquery_uri="jQuery/jquery.min.js"	# jQuery file name

# -- Section network
#
server_ip="127.0.0.1"	# SNIG Monitor Server
server_port="4422"	# SNIG Monitor Server Port

# -- Section snig_server
#
snig_server_dir=".."	# SNIG Monitor Server Root Directory

# -- Section website
#
cssprogressive="0"	# CSS progressive number to force reloads
development="true"	# Flag to enable development site specific parts
encoding="utf-8"	# Website default character encoding
service_recs_limit="50"	# Size of the default view of an entity service records
website="http://snig.rivetweb.org:8080"	# Website Name
