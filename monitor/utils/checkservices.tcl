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

proc ::ngis::out {m} { syslog -perror -ident snig -facility user info $m }
proc ::ngis::err {m} { syslog -perror -ident snig -facility user error $m }
proc ::ngis::print_help {} {
    puts {checkservice.tcl --option1 value --option2 value...

where recognized options are

  * --stalerecs check stale services status records. By default service status
                records last checked before 24h (this value can be changed with
                options '--nhours' and '--ndays'

  * --newrecs   starts a check run that searches for service record just registered
                by the harvesting procedure

  * --http0     searches for service status records of the url_status_codes tests that
                for some reason returned an invalid HTTP status code 0

  * --gids      Comma separated list of service records gids to be checked

  * --eids      Comma separated list of entity eid to be checked

  * --host      Comma separated list of host names to be checked

              The three options --host, --eids, --gids selection results are or'ed and
              therefore the selected record set is the union of their result sets

  * --limit <n> Only n check jobs are launched (default 20). By passing a value 0 
                the limit is disabled

  * --min-wait  
    --max-wait Minimum and maximum time (in seconds) between subsequent job sequence checks.
               The actual wait time is generated randomly between these extrema. Setting
               only the minimum forces constant rate of checks

  * --max-jobs Maximum number of jobs in every job sequence (default 20). If the search
               rules select for example 110 records these are checked in 5 20 jobs sequences
               and a final 10 jobs sequence}
} 

set sql_base { "select uri,ul.gid,description,ss.exit_info,ss.ts from testsuite.uris_long ul" \
               "join testsuite.service_status ss on ss.gid = ul.gid" }

set http0_sql       [concat $sql_base "where ss.exit_info like 'Invalid% 0'"]
set newservice_sql  [concat $sql_base "where ss.gid is null"]
set stalerecs_sql   [concat $sql_base "where ss.task = 'congruence'"]

# With Tcl9 these should become immutable variables

set fun             generic
set sql             $sql_base
set limit           20
set max_jobs_n      0
set min_jobs_per_seq 20
set jobs_seq_delay  5000
set nhours          24
set ndays           0
set min_wait        5
set max_wait       -1
set eid             0
set gids            ""
set hosts           ""

if {$argc > 0} {
    set arguments $argv
    while {[llength $arguments]} {
        set arguments [lassign $arguments a]

        switch -nocase -- $a {
            --eids -
            --eid {
                set arguments [lassign $arguments eid]
                if {[regexp {^\d+([ \t]*,[ \t]*\d+)*$} $eid] == 0} {
                    ::ngis::err "Invalid argument: --eid argument must be comma separated list of integers"
                    return
                }
                ::ngis::out "Restricting to eid in $eid"
            }
            --gids {
                set arguments [lassign $arguments gids]
                if {[regexp {^\d+([ \t]*,[ \t]*\d+)*$} $gids] == 0} {
                    ::ngis::err "Invalid argument: --gids argument must be comma separated list of integers"
                    return
                }
                ::ngis::out "Restricting to records in $gids"
            }
            --host -
            --hosts {
                set arguments [lassign $arguments hosts]
                if {[regexp {^(\w[\w\.]*)([ \t]*,[ \t]*(\w[\w\.]*))*$} $hosts] == 0} {
                    ::ngis::err "Invalid argument: --gids argument must be comma separated list of host names"
                    return
                }
                set hosts [lmap h [split $hosts ","] {
                    format "'%s'" $h
                }]
                set hosts [join $hosts ","]
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
            --min-wait {
                set arguments [lassign $arguments min_wait]
            }
            --max-wait {
                set arguments [lassign $arguments max_wait]
            }
            default {
                ::ngis::out "Unrecognized argument '$a'"
                ::ngis::print_help
                return
            }
        }
    }
} else {
    ::ngis::print_help
    return
}

#
# let's seed the random numbers generator

random seed [clock seconds]

set con [::ngis::clientio open_connection $::ngis::unix_socket_name]
::ngis::clientio query_server $con "FORMAT JSON" 104

if {$max_wait < $min_wait} {
    set max_wait [expr $min_wait + 1]
}
set delta_t [expr 1000*($max_wait - $min_wait)]

::ngis::out "Random wait time limits: $min_wait, $max_wait"

# allowing to specify both --ndays and --nhours. If --nhours argument is >= 24
# we disabled it since it's meant to specify a time lapse in hours within a single day

if {$ndays > 0} { 
    if {$nhours >= 24} { set nhours 0 }
    set nhours [expr $ndays*24 + $nhours] 
}

if {($fun == "stalerecs") || ($fun == "http0recs")} {
    if {$nhours > 0} {
        lappend sql "AND ss.ts < NOW() - INTERVAL '$nhours hours'"
    }
} elseif {$fun == "generic"} {
    lappend sql "WHERE ss.task = 'congruence'"
}

set clauses_l {}
if {$eid != 0} { lappend clauses_l "ul.eid IN ($eid)" }
if {$gids != ""} { lappend clauses_l "ul.gid IN ($gids)" }
if {$hosts != ""} { 
    set hostname_regexp { substring( ul.uri from '.*://([^/]*)' )}
    lappend clauses_l "$hostname_regexp in ($hosts)"
}

if {[llength $clauses_l] > 0} {
    set clauses [join $clauses_l " OR "]
    lappend sql "AND ($clauses)"
}

if {($fun == "stalerecs") || ($fun == "http0recs")} {
    lappend sql "ORDER BY ss.ts"
}
if {$limit != 0} { lappend sql "LIMIT $limit" }
#::ngis::out "sql (list): $sql"

set sql [join $sql " "]

::ngis::out "sql: $sql"

set resultset [::ngis::service exec_sql_query $sql]
# setting up the random number generator

set nrecs 0

set allrows [$resultset allrows]
set gids_l [lmap r $allrows { dict get $r gid }]
::ngis::out "processing [llength $gids_l] gids"

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

    # the random time is in ms

    set random_delta [random [expr 1 + $delta_t]]
    after [expr 1000*$min_wait + $random_delta]
}

::ngis::out "$njobs_to_process records processed for function $fun"

$resultset close
chan close $con
::ngis::out "Concluding task with args: $argv"

