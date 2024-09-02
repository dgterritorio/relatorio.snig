# -- service_db
#
#
#
package require tdbc
package require tdbc::postgres
package require syslog
package require ngis::msglogger
package require ngis::conf


namespace eval ::ngis::service {
    variable connector ""

    # -- exec_sql_query
    #
    # opens a connection to the database

    proc get_connector {} {
        return [list tdbc::postgres::connection new               \
                                     -user      $::ngis::USERNAME \
                                     -db        $::ngis::DB_NAME  \
                                     -password  $::ngis::PASSWORD \
                                     -port      $::ngis::PORT     \
                                     -host      $::ngis::HOST]
    }

    proc exec_sql_query {sql} {
        variable connector

        if {$connector == ""} { 
            set connector [eval [get_connector]]      
        }
        set sql_st [$connector prepare $sql]
        return [$sql_st execute]
    }

    proc update_task_results {task_results_d} {
        set tasks [dict get $task_results_d tasks]
        set gid   [dict get $task_results_d gid]

        set values_l {}
        foreach t $tasks {
            set task   [dict get $t task]
            set status [dict get $t status]
            if {$status == ""} { break }
            lassign $status jobname exit_status exit_info exit_trace exit_info timestamp
            lappend values_l "($gid,to_timestamp($timestamp),'$task','$exit_status','$exit_info')"
        }
        set    sql "INSERT INTO $::ngis::SERVICE_STATUS (gid,ts,task,exit_status,exit_info) "
        append sql "VALUES [join $values_l ","] "
        append sql "ON CONFLICT (gid,task) DO UPDATE SET "
        append sql "gid = EXCLUDED.gid, ts = EXCLUDED.ts, task = EXCLUDED.task, "
        append sql "exit_status = EXCLUDED.exit_status,exit_info = EXCLUDED.exit_info"
        puts $sql

        set query_res [exec_sql_query $sql]
        $query_res close
    }


    proc load_by_gid {service_gid} {
        variable connector

        set sql "SELECT DISTINCT $::ngis::COLUMN_NAMES FROM $::ngis::TABLE_NAME WHERE gid=$service_gid"
        set query_result [exec_sql_query $sql]

        set rowcount [$query_result rowcount]
        if {$rowcount == 1} {
            $query_result nextdict service_d
            set result $service_d
            #puts $result
            set code 0
        } elseif {$rowcount == 0} {
            set result "Invalid query: no record found for gid $service_gid"
            set code 1
        } else {
            set result "Inconsistent data for gid $service_gid"
            set code 1
        }
        $query_result close
        return -code $code -errorcode invalid_gid $result
    }

    proc load_by_entity {snig_entity args} {
        set as "-list"
        set limit 0
        set v  ""
        foreach a $args {
            switch -nocase -- $a {
                -resultset {
                    set as $a
                }
                -list {
                    set as $a
                }
                -limit {
                    set v "limit"
                }
                default {
                    if {$v != ""} {
                        set $v $a
                        set v ""
                    }
                }
            }
        }

        set sql \
        "SELECT $::ngis::COLUMN_NAMES FROM $::ngis::TABLE_NAME WHERE record_entity LIKE '$snig_entity' ORDER BY gid"

        if {$limit > 0} {
            append sql " LIMIT $limit"
        }
        puts "exec sql: $sql"
        set query_result [exec_sql_query $sql]
        if {$as == "-resultset"} {
            return $query_result
        }

        set snig_entities {}
        $query_result foreach -as dicts e { lappend snig_entities $e }
        $query_result close
        return $snig_entities
    }
    namespace export *
    namespace ensemble create

}

package provide ngis::servicedb 1.0
