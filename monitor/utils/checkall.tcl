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

proc ::ngis::fetch_gids {sql_l eid {min_age 0} {nrecs 0}} {
	if {$eid > 0} {
		lappend sql_l "AND eid=$eid"
	}
	if {$min_age > 0} {
		lappend sql_l "AND ss.ts < NOW() - INTERVAL '$min_age hours'"
	}

	lappend sql_l "ORDER BY ss.ts"
	if {$nrecs > 0} {
		set sql_t [join [concat $sql_l "LIMIT $nrecs"] " "]
	} else {
		set sql_t [join $sql_l " "]
	}

	puts $sql_t
	set resultset [::ngis::service exec_sql_query $sql_t]

	# setting up the random number generator

	set allrows [$resultset allrows]
	set gids_l [lmap r $allrows { dict get $r gid }]
	$resultset close
	return $gids_l
}
# let's seed the random numbers generator

random seed [clock seconds]

set con [::ngis::clientio open_connection $::ngis::unix_socket_name]
::ngis::clientio query_server $con "FORMAT JSON" 104

set sql { "select uri,ul.gid,ss.exit_info,ss.ts from testsuite.uris_long ul" 
          "left join testsuite.service_status ss on ss.gid=ul.gid"
	      "where ss.task = 'congruence'" }


set delay	1
set concurrency 0
set min_wait    1
set max_wait    -1
set limit       0
set eid			0
set min_days	0
set min_hours	0

if {$argc > 0} {
    set arguments $argv
    while {[llength $arguments]} {
        set arguments [lassign $arguments a]

        switch -nocase -- $a {
			--eid {
				set arguments [lassign $arguments eid]
			}
			--delay {
				set arguments [lassign $arguments js_delay]
				if {$js_delay > 0} {
					set jobs_seq_delay $js_delay
					::ngis::out "job sequence scheduling delay $jobs_seq_delay"
				} else {
					::ngis::out "The job sequence scheduling delay must be > 0"
				}
			}
			--concurrency {
				set arguments [lassign $arguments concurrency]
				if {![string is integer $concurrency]} {
					::ngis::out "The concurrency must be a positive integer"
				}
			}
			--min-age-days {
				set arguments [lassign $arguments min_days]
			}
			--min-age-hours {
				set arguments [lassign $arguments min_hours]
			}
            --min-wait {
                set arguments [lassign $arguments min_wait]
            }
            --max-wait {
                set arguments [lassign $arguments max_wait]
            }
			--limit {
				set arguments [lassign $arguments limit]
			}
		}
    }
}

if {$max_wait < $min_wait} {
    set max_wait [expr $min_wait + 1]
}

set delta_t [expr 1000*($max_wait - $min_wait)]
set nrecs 0
set njobs 0

set min_age [expr 24*$min_days + $min_hours]

set gids_l [::ngis::fetch_gids $sql $eid $min_age $limit]
::ngis::out "processing [llength $gids_l] gids"

set processed_services 0
while {[llength $gids_l] > 0} {

    if {$concurrency > 0} {
		set message_d [::ngis::clientio query_server $con "JOBLIST" 114]
		set njobs [dict get $message_d njobs]
		while {($concurrency > 0) && ($njobs >= $concurrency)} {
			after 5000
			set njobs [dict get [::ngis::clientio query_server $con "JOBLIST" 114] njobs]
		}
    }
    set gids_l [lassign $gids_l gid]

    ::ngis::clientio query_server $con "CHECK $gid" 102

	# the argumento to 'random' must be > 0

    set random_delta [random [expr 1 + $delta_t]]
    after [expr 1000*$min_wait + $random_delta]
    incr processed_services

}
::ngis::out "processed $processed_services records"

chan close $con
