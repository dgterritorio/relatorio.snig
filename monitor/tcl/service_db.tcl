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

    proc check_password {pwd} {
        return 1
    }

    proc update_task_results {task_results_l} {
        set values_l {}
        foreach t $task_results_l {
            set gid    [dict get $t job gid]
            set task   [dict get $t task]
            set status [dict get $t status]
            set uuid   [dict get $t job uuid]
            if {$status == ""} { break }
            lassign $status exit_status exit_info exit_trace exit_info timestamp task_duration

            # escaping single quotes in exit_info

            set exit_info [string map [list "'" "''"] $exit_info]

            lappend values_l "($gid,timezone('$::ngis::TIMEZONE',to_timestamp($timestamp)),'$task','$exit_status','$exit_info','$uuid',$task_duration)"
        }

        set    sql "INSERT INTO $::ngis::SERVICE_STATUS (gid,ts,task,exit_status,exit_info,uuid,task_duration) "
        append sql "VALUES [join $values_l ","] "
        append sql "ON CONFLICT (gid,task) DO UPDATE SET "
        append sql "gid = EXCLUDED.gid, ts = EXCLUDED.ts, task = EXCLUDED.task, "
        append sql "exit_status = EXCLUDED.exit_status,exit_info = EXCLUDED.exit_info, "
        append sql "task_duration = EXCLUDED.task_duration"
        ::ngis::logger emit "$sql"
        #puts $sql
        set query_res [exec_sql_query $sql]
        $query_res close

        set    sql "INSERT INTO $::ngis::SERVICE_LOG (gid,ts,task,exit_status,exit_info,uuid,task_duration) "
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

    # get_description

    proc get_description {service_l} {
        dict with service_l {
            if {[info exists description]} {
                return $description
            } elseif {[info exists entity]} {
                return $entity
            } else {
                return "Service record id: $gid"
            }
        }
    }

    # load_entity_record

    proc load_entity_record {eid} {
        variable connector

        set entity_d ""

        set query_result [exec_sql_query "SELECT * from $::ngis::ENTITY_TABLE_NAME WHERE eid=$eid"]
        if {[$query_result rowcount] > 0} {
            set result [$query_result nextdict entity_d]
        }
        $query_result close
        return $entity_d
    }

    namespace eval entity {
        proc get_description {entity_d} {
            dict with entity_d {
                if {[info exists description] && ([string trim $description] != "")} {
                    return $description
                } else {
                    return "Entity records for eid=$eid"
                }
            }
        }
        namespace export get_description
        namespace ensemble create
    }

    # load_series_by_gids --
    #
    # From a list of integers, meaning a set of gids of uris_long records
    # returns the list of the whole records. Gids that dond't correspond
    # to any record are dropped silently
    #

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
            $query_result close
            return $result
        } elseif {$rowcount == 0} {
            set result "Invalid query: no records found for any gids"
        } else {
            set result "Inconsistent data for gid series '$gids'"
        }
        $query_result close
        return -code error -errorcode invalid_gid $result

    }

    proc entity_service_records_sql {entity {limit ALL} {offset 0}} {

        set columns [lmap c [split $::ngis::COLUMN_NAMES ","] {
            list "ul.${c}"
        }]
        set columns [join $columns ","]
        set columns "${columns},ent.description entity_definition"
        set sql [list "SELECT $columns FROM $::ngis::TABLE_NAME ul" \
                      "JOIN $::ngis::ENTITY_TABLE_NAME ent on ent.eid=ul.eid"]
        if {[string is integer $entity]} {
            lappend sql "WHERE ul.eid=$entity"
        } else {
            lappend sql "WHERE ent.description LIKE '$entity'"
        }

        lappend sql "ORDER BY ul.uri,ul.gid LIMIT $limit OFFSET $offset"

        return [join $sql " "]
    }


    # query_row_count

    proc entity_service_recs_count {entity} {
        set query_result [exec_sql_query [entity_service_records_sql $entity]]
        set rowcount [$query_result rowcount]
        $query_result close
        return $rowcount
    }


    proc load_by_entity {snig_entity args} {
        set as          "-list"
        set limit       "ALL"
        set rowcount_f  false
        set offset      0

        for {set p 0} {$p < [llength $args]} {incr p} {
            set a [lindex $args $p]
            switch -nocase -- $a {
                -resultset -
                -list {
                    set as $a
                }
                -rowcount {
                    set rowcount_v [lindex $args [incr p]]
                    set rowcount_f true
                }
                -offset {
                    set offset [lindex $args [incr p]]
                }
                -limit {
                    set limit [lindex $args [incr p]]
                }
                default {
                    puts "unrecognized switch '$a'"
                }
            }
        }

        set query_result [exec_sql_query [entity_service_records_sql $snig_entity $limit $offset]]

        # TDBC documention claims with a great deal of prudence
        # that calling method 'rowcount' on a TDBC result set
        # in principle may invalidate the resultset interna status 
        # (thus requiring in case an extra query). We assume that
        # Postgresql handles this case properly
        if {[string is true $rowcount_f]} {
            upvar 1 $rowcount_v $rowcount_v
        
            set $rowcount_v [$query_result rowcount]
        }

        if {$as == "-resultset"} { return $query_result }

        set snig_entities {}
        $query_result foreach -as dicts e {
            #if {![dict exists $e description]} {
            #    dict set e description "Undefined description"
            #}
            lappend snig_entities $e
        }
        $query_result close
        return $snig_entities
    }

    proc list_entities {pattern {order "-nrecs"} {field "-description"}} {
        set sql [list "SELECT e.eid eid,e.description description,count(ul.gid) count" \
                      "FROM $::ngis::ENTITY_TABLE_NAME e" \
                      "LEFT JOIN $::ngis::TABLE_NAME ul ON ul.eid=e.eid"]

        if {$field == "-description"} {
            lappend sql "WHERE e.description LIKE '$pattern'"
        } else {
            set field [string range $field 1 end]
            lappend sql "WHERE e.${field} = '$pattern'"
        }
        if {$order == "-nrecs"} {
            lappend sql "GROUP BY e.eid ORDER BY count DESC"
        } elseif {$order == "-alpha"} {
            lappend sql "GROUP BY e.eid ORDER BY e.description"
        }
        set sql [join $sql " "]
        #puts $sql

        set query_result [exec_sql_query $sql]
        set entities [$query_result allrows -as lists]
        $query_result close
        return $entities
    }

    # service_data --
    #
    # loads services having a given description pattern or gid or eid
    #
    #

    proc service_data {pattern} {
        set ul_columns "ul.*"
        set ss_columns "ss.ts,ss.task,ss.exit_status,ss.exit_info,ss.uuid"
        set ent_columns "ent.description entity_definition"

        set     sql [list "SELECT $ul_columns,$ss_columns,$ent_columns from $::ngis::TABLE_NAME ul"]
        lappend sql "LEFT JOIN $::ngis::SERVICE_STATUS ss ON ul.gid=ss.gid"
        lappend sql "JOIN $::ngis::ENTITY_TABLE_NAME ent ON ul.eid=ent.eid"

        if {[string is integer $pattern]} {
            lappend sql "WHERE ul.gid=$pattern"
        } elseif {[regexp {gid=(\d+)} $pattern -> gid]} {
            lappend sql "WHERE ul.gid=$gid"
        } elseif {[regexp {eid=(\d+)} $pattern -> eid]} {
            lappend sql "WHERE ul.eid=$eid"
        } else {
            lappend sql "WHERE ul.description LIKE '$pattern'"
        }

        set sql [join $sql " "]
        set query_result [exec_sql_query $sql]

        #puts "SQL: $sql"

        set services_d [dict create]
        $query_result foreach -as dicts s_d {
            dict with s_d {
                #puts "RES: $s_d"
                if {![dict exists $services_d $gid]} {
                    dict set services_d $gid [dict filter $s_d key {*}[split $::ngis::COLUMN_NAMES ","] eid entity_definition]
                    if {![dict exists $services_d $gid description]} {
                        dict set services_d $gid description "undefined description for primary key '$gid'"
                    }
                    if {![info exists entity_definition]} {
                        dict set services_d $gid entity_definition "undefined entity definition (eid=$eid)"
                    } else {
                        dict set services_d $gid entity_definition "$entity_definition (eid=$eid)"
                    }
                }

                # service records for which no task has ever been performed don't have a 'task'
                # element defined (NULL in the query result)

                if {[info exists task]} {
                    dict set services_d $gid tasks $task [dict filter $s_d key exit_status exit_info uuid ts]
                }
            }
        }

        $query_result close
        #puts "==========\n$services_d\n========="
        #return $services_d
        return [dict values $services_d]
    }

    proc remove_task_results {gid tasks_to_purge_l} {
        set conditions [lmap t $tasks_to_purge_l {
            set cond "task='$t'"
        }]

        set where_clause "gid=$gid AND ([join $conditions " OR "])"

        set sql "DELETE FROM $::ngis::SERVICE_STATUS WHERE $where_clause"
        set query_result [exec_sql_query $sql]

        $query_result close
    }

    namespace export *
    namespace ensemble create
}

package provide ngis::servicedb 1.0
