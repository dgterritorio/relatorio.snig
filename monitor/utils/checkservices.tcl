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
# importing Tclx too for its random number generator
package require Tclx
package require fileutil

proc ::ngis::out {m} {
    syslog -perror -ident snig -facility user info $m
}


# let's seed the random numbers generator

random seed [clock seconds]

set con [::ngis::clientio open_connection $::ngis::unix_socket_name]
::ngis::clientio query_server $con "FORMAT JSON" 104

set http0_sql {"select uri,ul.gid,description,ss.exit_info,ss.ts from testsuite.uris_long ul" 
               "join testsuite.service_status ss on ss.gid = ul.gid where ss.exit_info like 'Invalid% 0'"}

set newservice_sql {"select uri,ul.gid,description,ss.exit_info,ss.ts from testsuite.uris_long ul" 
                    "left join testsuite.service_status ss on ss.gid = ul.gid where ss.gid is null"}

set stalerecs_sql { "select uri,ul.gid,ss.exit_info,ss.ts from testsuite.uris_long ul" 
                    "left join testsuite.service_status ss on ss.gid=ul.gid"
                    "where ss.task = 'congruence' and ss.exit_info != 'Invalid% 0'"}

# With Tcl9 this should become an immutable variable
set min_jobs_per_seq 20

set fun         http0recs
set sql         $http0_sql
set limit       20
set max_jobs_n  0
set jobs_seq_delay 5000
set nhours      24
set ndays       0
set min_wait    100
set max_wait    4000
set eid         ""

if {$argc > 0} {
    set arguments $argv
    while {[llength $arguments]} {
        set arguments [lassign $arguments a]

        switch -nocase -- $a {
	    --eid {
		set arguments [lassign $arguments eid]
                ::ngis::out "Restricting to eid = $eid"
	    }
            --stalerecs {
                set fun stalerecs
                set sql $stalerecs_sql
                ::ngis::out "Check for stale records"
            }
            --newrecs {
                set fun newrecs
                set sql $newservice_sql
                ::ngis::out "Check new records"
            }
            --nhours {
                set arguments [lassign $arguments nhours]
                ::ngis::out "Checking records older than $nhours hours"
            }
            --ndays {
                set arguments [lassign $arguments ndays]
                ::ngis::out "Checking records older than $ndays days"
            }
            --http0 {
                set fun http0recs
                set sql $http0_sql
                ::ngis::out "Checking HTTP 0 status records last checked more than $nhours hours ago"
            }
            --limit {
                set arguments [lassign $arguments limit]
                ::ngis::out "Limit to $limit results"
            }
            --max-jobs {
                set arguments [lassign $arguments max_jobs_n]
                ::ngis::out "set maximum concurrent jobs as $max_jobs_n"
            }
	    --seq-delay {
		set arguments [lassign $arguments js_delay]
		if {$js_delay > 0} {
		    set jobs_seq_delay $js_delay
		    ::ngis::out "job sequence scheduling delay $jobs_seq_delay"
		} else {
		    ::ngis::out "The job sequence scheduling delay must be > 0"
		}
	    }
            --min-wait {
                set arguments [lassign $arguments min_wait]
            }
            --max-wait {
                set arguments [lassign $arguments max_wait]
            }
            default {
                ::ngis::out "Unrecognized argument '$a'"
            }
        }

    }
}

::ngis::out "Random wait time limits: $min_wait, $max_wait"

# allowing to specify both --ndays and --nhours. If --nhours argument is >= 24
# we disabled it since it's meant to specify a time lapse in hours within a single day

if {$ndays > 0} { 
    if {$nhours >= 24} { set nhours 0 }
    set nhours [expr $ndays*24 + $nhours] 
}

if {($fun == "stalerecs") || ($fun == "http0recs")} {
    if {$nhours > 0} {
        lappend sql "and ss.ts < NOW() - INTERVAL '$nhours hours'"
    }
}

if {$eid != 0} {
    lappend sql "AND ul.eid = $eid"
}

if {($fun == "stalerecs") || ($fun == "http0recs")} {
    lappend sql "order by ss.ts"
}
if {$limit != 0} { lappend sql "LIMIT $limit" }

set sql [join [subst $sql] " "]

::ngis::out "sql: $sql"

set resultset [::ngis::service exec_sql_query $sql]
# setting up the random number generator

set delta_t [expr $max_wait - $min_wait]
set nrecs 0

set allrows [$resultset allrows]
set gids_l [lmap r $allrows { dict get $r gid }]
::ngis::out "processing gids: $gids_l"

set returned_message_d [::ngis::clientio query_server $con "JOBLIST" 114]
set njobs [dict get $returned_message_d njobs]

if {(($fun == "stalerecs") || ($fun == "http0recs")) && ($njobs > 0)} {
    ::ngis::out "Monitor busy: refusing to start more jobs"
    exit
}

::ngis::out "checking [llength $gids_l] services"

if {$max_jobs_n == 0} { set max_jobs_n $min_jobs_per_seq }
::ngis::out "Creating Job Sequences of $max_jobs_n jobs max"

set njobs_to_process [llength $gids_l]
while {[llength $gids_l] > 0} {
    set service_l {}
    for {set n 0} {($n < $max_jobs_n) && [llength $gids_l]} {incr n} {
        set gids_l [lassign $gids_l j]
        lappend service_l $j
    }
    if {[llength $service_l]} {
        ::ngis::clientio query_server $con "CHECK $service_l" 102
        ::ngis::out "Created Job Sequence for [llength $service_l] jobs"
    }
    after $jobs_seq_delay
}

::ngis::out "$njobs_to_process records processed for function $fun"

$resultset close
chan close $con
::ngis::out "Concluding task with args: $argv"

