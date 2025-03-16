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
                 "and ss.ts < NOW() - INTERVAL '$nhours hours' order by ss.ts"}

append newservice_sql {"select uri,ul.gid,description,ss.exit_info,ss.ts from testsuite.uris_long ul" 
		              "left join testsuite.service_status ss on ss.gid=ul.gid where ss.gid is null"}


append stalerecs_sql {"select ul.uri,ul.gid,ul.description,ss.exit_info,ss.ts from testsuite.uris_long ul" 
		              "join testsuite.service_status ss on ss.gid=ul.gid where ss.task='congruence'" 
                      "and ss.ts < NOW() - INTERVAL '$nhours hours' order by ss.ts"}

set fun         http0recs
set sql         $http0_sql
set limit       20
set max_jobs_n  0
set nhours      24
set ndays       0
set min_wait    100
set max_wait    4000

if {$argc > 0} {
    set arguments $argv
    while {[llength $arguments]} {
        set arguments [lassign $arguments a]

        switch -nocase -- $a {
            --stalerecs {
                set fun stalerecs
                set sql $stalerecs_sql
                syslog -perror -ident snig -facility user info "Check for stale records"
            }
            --newrecs {
                set fun newrecs
                set sql $newservice_sql
                syslog -perror -ident snig -facility user info "Check new records"
            }
            --nhours {
                set arguments [lassign $arguments nhours]
                syslog -perror -ident snig -facility user info "Checking records older than $nhours hours"
            }
            --ndays {
                set arguments [lassign $arguments ndays]
                syslog -perror -ident snig -facility user info "Checking records older than $ndays days"
            }
            --http0 {
                set fun http0recs
                set sql $http0_sql
                syslog -perror -ident snig -facility user info "Checking HTTP 0 status records last checked more than $nhours hours ago"
            }
            --limit {
                set arguments [lassign $arguments limit]
                syslog -perror -ident snig -facility user info "Limit to $limit results"
            }
            --max-jobs {
                set arguments [lassign $arguments max_jobs_n]
                syslog -perror -ident snig -facility user info "set maximum concurrent jobs as $max_jobs_n"
            }
            --min-wait {
                set arguments [lassign $arguments min_wait]
            }
            --max-wait {
                set arguments [lassign $arguments max_wait]
            }
            default {
                syslog -perror -ident snig -facility user info "Unrecognized argument '$a'"
            }
        }

    }
}

syslog -perror -ident snig -facility user info "Random wait time limits: $min_wait, $max_wait "

# allowing to specify both --ndays and --nhours. If --nhours argument is >= 24
# we disabled it since it's meant to specify a time lapse in hours within a single day

if {$ndays > 0} { 
    if {$nhours >= 24} { set nhours 0 }
    set nhours [expr $ndays*24 + $nhours] 
}

set sql [join [subst $sql] " "]

puts $sql

if {$limit != 0} { append sql " LIMIT $limit" }
syslog -perror -ident snig -facility user info "sql: $sql"

set resultset [::ngis::service exec_sql_query $sql]
# setting up the random number generator

set delta_t [expr $max_wait - $min_wait]
set nrecs 0
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
    incr nrecs

    after [expr $min_wait + [random $delta_t]]
}

syslog -perror -ident snig -facility user info "$nrecs records processed for function $fun"

$resultset close
chan close $con
syslog -perror -ident snig -facility user info "Concluding task with args: $argv"

