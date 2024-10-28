# protocol.tcl --
#
#
#
#

package require ngis::common
package require ngis::hrformat
package require ngis::jsonformat

catch { ::ngis::Protocol destroy }

oo::class create ngis::Protocol

oo::define ngis::Protocol {
    variable formatter
    variable CodeMessages
    variable ds_nseq
    variable nseq
    variable hr_formatter
    variable json_formatter

    constructor {} {
        set hr_formatter    [::ngis::HRFormat create [::ngis::Formatters new_cmd hr]]
        set json_formatter  [::ngis::JsonFormat create [::ngis::Formatters new_cmd json]]

        # setting the default
        set formatter $hr_formatter
    }

    destructor {
    }

    method format {} {
        return [$formatter format]
    }

    method set_format {f} {
        switch -nocase $f {
            HR {
                set formatter $hr_formatter
            }
            JSON {
                set formatter $json_formatter
            }
            default {
                return -code 1 "Invalid formatter: must be either HR or JSON"
            }
        }
    }

    # resource_check
    #
    # parses the arguments of command CHECK and builds job sequences
    # to be thrown to the job_controller
    #
    # forms to be detected are:
    #
    #   1. pure integer: gid of a resource rec in uris_long
    #   2. gid=<int>: synonimous of the former
    #   3. eid=<int>: integer primary key to an entity.
    #   4. pure text: entity definition. Does the same

    method resource_check_parser {arguments} {
        set gids_l {}
        set eids_l {}
        set entities_l {}
        set retstatus OK
        foreach a $arguments {
            #set a [string tolower $a]

            if {[string is integer $a] && ($a > 0)} {
                lappend gids_l $a
            } elseif {[regexp {(eid|gid)=(\d+)} $a m type primary_id] && \
                      [string is integer $primary_id] && ($primary_id > 0)} {

                if {$type == "eid"} {
                    lappend eids_l $primary_id
                } elseif {$type == "gid"} {
                    lappend gids_l $primary_id
                } else {
                    return [list ERR "009" $a]
                }

            } else {
                # ::ngis::service list_entities returns a list of 3-element descriptors
                # (as a matter of fact a record in the entities table with columsn stripped of the keys)
                lappend entities_l {*}[::ngis::service list_entities $a]
            }
        }

        if {([llength $gids_l] == 0) && ([llength $eids_l] == 0) && \
            ([llength $entities_l] == 0)} {
            return [list ERR "009" "No valid records found"]
        }
        return [list $retstatus $gids_l $eids_l $entities_l]
    }

    method compose {code args} {
        return [eval $formatter c${code} $args]
    }

    method parse_cmd {cmd_line} {
        set cmd_line [string trim $cmd_line]
        puts "msg >$cmd_line< ([string length $cmd_line])"
        if {[regexp -nocase {^(\w+)\s*.*$} $cmd_line m cmd] == 0} {
            return "001: unrecognized command '$cmd_line'"
        } else {
            
            if {[regexp {^([A-Z]+)\s+(.*)$} $cmd_line m cmd arguments] == 0} {
                set arguments ""
            }

            puts "arguments: '$arguments' (nargs: [llength $arguments])"
            switch $cmd {
                REGTASKS {
                    return [my compose 110 [::ngis::tasks list_registered_tasks]]
                }
                ENTITIES {
                    set order "-nrecs"
                    set pattern "%"
                    if {[llength $arguments] > 0} {
                        foreach a $arguments {
                            if {$a == "-alpha"} {
                                set order $a
                            } else {
                                set pattern $a
                            }
                        }
                    }
                    return [my compose 108 [::ngis::service::list_entities $pattern $order]]
                }
                CHECK {
                    set parsed_results [lassign [my resource_check_parser $arguments] res_status]
                    if {$res_status == "OK"} {
                        lassign $parsed_results gids_l eids_l entities_l
                        set job_controller [$::ngis_server get_job_controller]
                        if {[llength $gids_l] > 0} {
                            set service_l [::ngis::service load_series_by_gids $gids_l]
                            if {[llength $service_l]} {
                                $job_controller post_sequence [::ngis::JobSequence create [::ngis::Sequences new_cmd]   \
                                                [::ngis::PlainJobList create [::ngis::DataSources new_cmd] $service_l]  \
                                                "Series of [llength $service_l] records"]
                            } else {
                                return [my compose 005 $gids_l]
                            }
                        }
                        if {[llength $eids_l] > 0} {
                            foreach eid $eids_l {    
                                set entity_d [::ngis::service load_entity_record $eid]
                                if {[dict size $entity_d] > 0} {
                                    set entity [dict get $entity_d description]
                                    set resultset [::ngis::service load_by_entity $eid -resultset]
                                    $job_controller post_sequence [::ngis::JobSequence create [::ngis::Sequences new_cmd] \
                                                    [::ngis::DBJobSequence create [::ngis::DataSources new_cmd] $resultset] $entity]
                                } else {
                                    ::ngis::logger emit "No entity record found for eid $eid"
                                }
                            }
                        }
                        if {[llength $entities_l]} {
                            foreach entity $entities_l {
                                set entity_description [lindex $entity 1]
                                set resultset [::ngis::service load_by_entity $entity_description -resultset]
                                $job_controller post_sequence [::ngis::JobSequence create [::ngis::Sequences new_cmd] \
                                        [::ngis::DBJobSequence create [::ngis::DataSources new_cmd] $resultset] $entity_description]
                            }
                        }
                        
                        return [my compose 002]
                    } else {
                        lassign $parsed_results code a
                        return [my compose $code $a]
                    }
                }
                STOP {
                    [$::ngis_server get_job_controller] stop_operations
                    return [my compose 102]
                }
                QUERY {
                    set jc_status [[$::ngis_server get_job_controller] status]
                    set tm_status [[$::ngis_server get_job_controller] status "thread_master"]
                    return [my compose 106 $jc_status $tm_status]
                }
                FORMAT {
                    if {[string length $arguments] == 0} {
                        return [my compose 104 [$formatter format]]
                    } else {
                        set fmt $arguments
                        switch -nocase $fmt {
                            HR   { set formatter $hr_formatter }
                            JSON { set formatter $json_formatter }
                            default {
                                return [my compose 013 $fmt]
                            }
                        }
                        return [$formatter c104]
                    } else {
                        return [my compose 003 $arguments]
                    }
                }
                WHOS {
                    return [my compose 112 [$::ngis_server whos]]
                }
                SET {

                }
                EXIT {
                    $::ngis_server shutdown
                    return [my compose 000]
                }
                default {
                    return [my compose 001 $msg]
                }
            }
        }
    }
}

namespace eval ::ngis::Protocol {
    proc mkprotocol {} { return [::ngis::Protocol new] }
}

package provide ngis::protocol 1.1
