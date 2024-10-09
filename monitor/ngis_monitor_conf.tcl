namespace eval ::ngis {

    variable HOST               "127.0.0.1"
    variable USERNAME           "dgt"
    variable PASSWORD           "W8a1kCUOx0mupUAF"
    variable DB_NAME            "snig"
    variable TABLE_NAME         "testsuite.uris_long"
    variable ENTITY_TABLE_NAME  "testsuite.entities"
    variable SERVICE_STATUS     "testsuite.service_status"
    variable PORT               "5432"
    variable COLUMN_NAMES       "gid,uuid,uri,entity,description,uri_type,version"
    variable SERVICE_STATUS     "testsuite.service_status"
    variable SERVICE_LOG        "testsuite.service_log"
    variable TIMEZONE           "Europe/Lisbon"
    variable data_root          [file join / tmp snig]

    variable max_workers_number 50
    variable unix_socket_name   /tmp/ngis.socket
    variable end_of_answer      "----"
    variable rescheduling_delay 100
    variable curldir            "" 

    variable tcpaddr            127.0.0.1
    variable tcpport            4422
}

package provide ngis::conf 1.1
