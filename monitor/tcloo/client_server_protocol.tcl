# protocol.tcl --
#
# The server creates an instance of protocol for each connection
# The overhead of doing this is justified by the small number of
# connections simultaneously open on the server with the benefit of
# not keeping track of a session state
#
#

package require ngis::common
package require ngis::csprotomap
package require ngis::hrformat
package require ngis::jsonformat

oo::class create ngis::Protocol

oo::define ngis::Protocol {
    variable formatter
    variable CodeMessages
    variable ds_nseq
    variable nseq
    variable hr_formatter
    variable json_formatter

    constructor {} {
        set hr_formatter    [::ngis::HRFormat   create [::ngis::Formatters new_cmd hr]]
        set json_formatter  [::ngis::JsonFormat create [::ngis::Formatters new_cmd json]]

        # setting the default
        set formatter $hr_formatter
    }

    destructor { }

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

    method current_formatter {} { return $formatter }

    # resource_check_parser (and loader, see below)
    #
    # parses the arguments of command CHECK and builds job sequences
    # to be thrown to the job_controller
    #
    # forms to be detected are:
    #
    #   1. pure integer: gid of a resource rec in uris_long
    #   2. gid=<int>: synonimous of the former
    #   3. eid=<int>: integer primary key to an entity.
    #   4. pure text: entity or record definition.
    #
    # TODO: This procedure is badly designed and needs reform.
    # It combines argument parsing and value estration to real
    # data retrieval for two classes of information, entities and
    # URL services records (table uris_long). Such hybrid behavior
    # is a temporary solution and needs cleaner design
    #

    method resource_check_parser {arguments {class entities}} {
        set gids_l {}
        set eids_l {}
        set resources_l {}
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
                }

            } else {
                switch $class {
                    entities {
                        # ::ngis::service list_entities returns a list of 3-element descriptors
                        # (as a matter of fact a record in the entities table with columsn stripped of the keys)
                        lappend resources_l {*}[::ngis::service list_entities $a]
                    }
                    services {
                        # ::ngis::service list_servicces returns 
                        lappend resources_l {*}[::ngis::service service_data $a]
                    }
                }
            }
        }

        if {([llength $gids_l] == 0) && ([llength $eids_l] == 0) && \
            ([llength $resources_l] == 0)} {
            return [list ERR "109" "No valid records found"]
        }
        return [list $retstatus $gids_l $eids_l $resources_l]
    }

    method parse_exec_cmd {cmd_line} {
        set cmd_line [string trim $cmd_line]
        puts "msg >$cmd_line< ([string length $cmd_line])"
        if {[regexp -nocase {^(\w+)\s*.*$} $cmd_line m cmd] == 0} {
            return "101: unrecognized or invalid command '$cmd_line'"
        } else {
            
            # we require the protocol command to be strictly uppercase for
            # best reading of errors and log lines

            if {[regexp {^([A-Z]+)\s+(.*)$} $cmd_line m cmd arguments] == 0} {
                set arguments ""
            }

            if {[dict exists $::cs_protocol $cmd]} {
                set cmd_o [dict get $::cs_protocol $cmd]
                return [eval $formatter [$cmd_o exec {*}$arguments]]
            }

            puts "arguments: '$arguments' (nargs: [llength $arguments])"
            switch $cmd {
                CHECK {
                    set parsed_results [lassign [my resource_check_parser $arguments] res_status]
                    if {$res_status == "OK"} {
                        lassign $parsed_results gids_l eids_l entities_l
                        set job_controller [$::ngis_server get_job_controller]
                        if {[llength $gids_l] > 0} {
                            set service_l [::ngis::service load_series_by_gids $gids_l]
                            set jseq_des "Series of [llength $service_l] records"
                            if {[llength $service_l] > 0} {
                                # if it's a single service job we set as job sequence description
                                # the 'description' columns in table uris_long
                                if {[llength $service_l] == 1} {
                                    set jseq_des [::ngis::service get_description [lindex $service_l 0]]
                                }
                                $job_controller post_sequence [::ngis::JobSequence create [::ngis::Sequences new_cmd]   \
                                                [::ngis::PlainJobList create [::ngis::DataSources new_cmd] $service_l]  \
                                                $jseq_des]
                            } else {
                                return [$formatter c105]
                            }
                        }
                        if {[llength $eids_l] > 0} {
                            foreach eid $eids_l {    
                                set entity_d [::ngis::service load_entity_record $eid]
                                if {[dict size $entity_d] > 0} {
                                    set entity [::ngis::service::entity get_description $entity_d]
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

                        return [$formatter c102]
                    } else {
                        lassign $parsed_results code a
                        return [$formatter c$code $a]
                    }
                }
                STOP {
                    [$::ngis_server get_job_controller] stop_operations
                    ::ngis::logger emit "got a 'stop_operations' signal"
                    return [$formatter c502]
                }
                EXIT {
                    $::ngis_server shutdown
                    return [$formatter c100]
                }
                default {
                    return [$formatter c101 $msg]
                }
            }
        }
    }
}

namespace eval ::ngis::Protocol {
    proc mkprotocol {} { return [::ngis::Protocol new] }
}

package provide ngis::protocol 2.0
