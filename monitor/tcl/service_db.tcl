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

    proc update_task_results {tasks_list} {
        set values_l {}
        foreach t $tasks_list {
            set gid    [dict get $t job gid]
            set task   [dict get $t task]
            set status [dict get $t status]
            set uuid   [dict get $t job uuid]
            if {$status == ""} { break }
            lassign $status exit_status exit_info exit_trace exit_info timestamp
            lappend values_l "($gid,timezone('$::ngis::TIMEZONE',to_timestamp($timestamp)),'$task','$exit_status','$exit_info','$uuid')"
        }

        set    sql "INSERT INTO $::ngis::SERVICE_STATUS (gid,ts,task,exit_status,exit_info,uuid) "
        append sql "VALUES [join $values_l ","] "
        append sql "ON CONFLICT (gid,task) DO UPDATE SET "
        append sql "gid = EXCLUDED.gid, ts = EXCLUDED.ts, task = EXCLUDED.task, "
        append sql "exit_status = EXCLUDED.exit_status,exit_info = EXCLUDED.exit_info"
        #puts $sql
        set query_res [exec_sql_query $sql]
        $query_res close

        set    sql "INSERT INTO $::ngis::SERVICE_LOG (gid,ts,task,exit_status,exit_info,uuid) "
        append sql "VALUES [join $values_l ","] "
        #puts $sql
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

    proc load_series_by_gids {gids} {
        variable connector

        set where_clause {}
        foreach gid $gids {
            lappend where_clause "gid=$gid"
        }
        set where_clause [join $where_clause " OR "]
        set sql "SELECT DISTINCT $::ngis::COLUMN_NAMES FROM $::ngis::TABLE_NAME WHERE $where_clause"
        set query_result [exec_sql_query $sql]

        set rowcount [$query_result rowcount]
        if {$rowcount >= 1} {
            set result [$query_result allrows -as dicts]
            set code 0
        } elseif {$rowcount == 0} {
            set result "Invalid query: no records found for ani gids"
            set code 1
        } else {
            set result "Inconsistent data for gid series '$gids'"
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
        "SELECT $::ngis::COLUMN_NAMES FROM $::ngis::TABLE_NAME WHERE entity LIKE '$snig_entity' ORDER BY gid"

        if {$limit > 0} {
            append sql " LIMIT $limit"
        }
        #puts "exec sql: $sql"
        set query_result [exec_sql_query $sql]
        if {$as == "-resultset"} {
            return $query_result
        }

        set snig_entities {}
        $query_result foreach -as dicts e { lappend snig_entities $e }
        $query_result close
        return $snig_entities
    }

    proc list_entities {pattern} {

        set sql [list "SELECT e.eid eid,e.description description,count(ul.gid) count" \
                      "from $::ngis::ENTITY_TABLE_NAME e" \
                      "LEFT JOIN $::ngis::TABLE_NAME ul ON ul.eid=e.eid"]
        #set sql [list "SELECT eid,description from $::ngis::ENTITY_TABLE_NAME"]
        if {$pattern != ""} {
            lappend sql "WHERE e.description LIKE '$pattern'"
        }
        lappend sql "GROUP BY e.eid ORDER BY count DESC"
        set sql [join $sql " "]
        puts $sql

        set query_result [exec_sql_query $sql]
        set entities [$query_result allrows -as lists]
        $query_result close
        return $entities
    }

    namespace export *
    namespace ensemble create
}

package provide ngis::servicedb 1.0
