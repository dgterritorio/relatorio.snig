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
    variable SERVICE_LOG        "testsuite.service_log"
    variable TIMEZONE           "Europe/Lisbon"

    variable data_root          [file join / tmp snig]
    variable snig_server_root   [file normalize [file dirname [info script]]]
    variable docs_base          [file join $snig_server_root doc]
    variable tasks_dir          [file join $snig_server_root tasks]
    variable debugging          false

    variable task_results_queue_size 10
    variable max_workers_number 5
    variable batch_num_jobs     10

    variable debug_task_delay   5000
    variable task_delay         100

    variable unix_socket_name   /tmp/snig.socket
    variable rescheduling_delay 100
    variable curldir            "" 

    variable authorship         {NATURAL GIS LDA - P.IVA 508912032 (PT)}
    variable bug_reports        "https://github.com/dgterritorio/relatorio.snig/issues"

    variable tcpaddr            "127.0.0.1"
    variable tcpport            "4422"
}

package provide ngis::conf 1.1
