#!/usr/bin/tclsh
#
# carefully and silently testing services that returned HTTP 0 codes
#

package require json

# assuming the monitor configuration is in the parent directory
set current_dir [file normalize [file join [file dirname [info script]] ..]]

cd $current_dir

set curr_dir_pos [lsearch $auto_path $current_dir]
if {$curr_dir_pos < 0} {
    set auto_path [concat $current_dir $auto_path]
} elseif {$current_dir_pos > 0} {
    set auto_path [concat $current_dir [lreplace $auto_path $current_dir_pos $current_dir_pos]]
}

package require syslog
package require unix_sockets
package require tdbc
package require tdbc::postgres
package require ngis::servicedb
package require ngis::conf
package require ngis::clientio

# drawing on Tclx too for its random number generator
#
package require Tclx

random seed [clock seconds]

set con [::ngis::clientio open_connection $::ngis::unix_socket_name]
::ngis::clientio query_server $con "FORMAT JSON" 104
puts "protocol format set as JSON"

append http0_sql {"select uri,ul.gid,description,ss.exit_info,ss.ts from testsuite.uris_long ul" 
                 "join testsuite.service_status ss on ss.gid=ul.gid where ss.exit_info like 'Invalid% 0'" 
                 "and ss.ts < NOW() - INTERVAL '$nhours hours' order by ul.gid"}

append newservice_sql {"select uri,ul.gid,description,ss.exit_info,ss.ts from testsuite.uris_long ul" 
		              "left join testsuite.service_status ss on ss.gid=ul.gid where ss.gid is null"}

set sql $http0_sql
set limit 20
set max_jobs_n 0
set nhours 24
if {$argc > 0} {
    set arguments $argv
    while {[llength $arguments]} {
        set arguments [lassign $arguments a]

        switch -nocase -- $a {
            -newrecs {
                syslog -perror -ident snig -facility user info "Check new records"
                set sql $newservice_sql
            }
            -nhours {
                set arguments [lassign $arguments nhours]
                syslog -perror -ident snig -facility user info "Checking HTTP 0 recors older than $nhours hours"
            }
            -http0 {
                set sql $http0_sql
            }
            -limit {
                set arguments [lassign $arguments limit]
                syslog -perror -ident snig -facility user info "Limit to $limit results"
            }
            -max-jobs {
                set arguments [lassign $arguments max_jobs_n]
                syslog -perror -ident snig -facility user info "set maximum concurrent jobs as $max_jobs_n"
            }
            default {
                syslog -perror -ident snig -facility user info "Unrecognized argument '$a'"
            }
        }

    }
}

set sql [join [subst $sql] " "]

if {$limit != 0} { append sql " LIMIT $limit" }
syslog -perror -ident snig -facility user info "sql: $sql"

set resultset [::ngis::service exec_sql_query $sql]
# setting up the random number generator

while {[$resultset nextdict service_d]} {
    dict with service_d {
        if {![info exists description]} { set description "" }
        syslog -perror -ident snig -facility user info "check service with gid $gid ($description)"
        ::ngis::clientio query_server $con "CHECK $gid" 102

        set njobs 1
        while {$njobs > $max_jobs_n} {
            set returned_message_d [::ngis::clientio query_server $con "JOBLIST" 114]
            set njobs [dict get $returned_message_d njobs]
            after 2000
        }
    }

    # wait for min 100 ms, max 4 secs

    after [expr 100 + [random 1900]]
}
$resultset close
chan close $con
syslog -perror -ident snig -facility user info "Concluding task with args: $argv"

