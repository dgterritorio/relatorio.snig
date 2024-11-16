# protocol.tcl --
#
# The server creates an instance of protocol for each connection
# The overhead of doing this is justified by the small number of
# connections simultaneously open on the server with the benefit of
# not keeping track of a session state
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
            return "101: unrecognized command '$cmd_line'"
        } else {
            
            # we require the protocol command to be strictly uppercase for
            # best reading of errors and log lines

            if {[regexp {^([A-Z]+)\s+(.*)$} $cmd_line m cmd arguments] == 0} {
                set arguments ""
            }

            puts "arguments: '$arguments' (nargs: [llength $arguments])"
            switch $cmd {
                REGTASKS {
                    return [$formatter c110 [::ngis::tasks list_registered_tasks]]
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
                    return [$formatter c108 [::ngis::service::list_entities $pattern $order]]
                }
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
                JOBLIST {
                    set job_controller [$::ngis_server get_job_controller]
                    set job_sequences [$job_controller job_sequences]
                    set jobs_l [lmap s $job_sequences {
                        set aj [$s active_jobs]
                        lmap j $aj {
                            set sj [$j serialize]
                            dict with sj {
                                list $gid $description $uri_type $version $job_status $timestamp
                            }
                        }
                    }]
                    set jobs_l [eval concat $jobs_l]
                    return [$formatter c114 $jobs_l]
                }
                STOP {
                    [$::ngis_server get_job_controller] stop_operations
                    ::ngis::logger emit "got a 'stop_operations' signal"
                    return [$formatter c502]
                }
                QUERY {
                    set jc_status [[$::ngis_server get_job_controller] status]
                    set tm_status [[$::ngis_server get_job_controller] status "thread_master"]
                    return [$formatter c106 $jc_status $tm_status]
                }
                QSERVICE {
                    # returns data regarding a series of service records (as specified by
                    # mixed forms arguments in analogy with command CHECK)

                    set parsed_results [lassign [my resource_check_parser $arguments "services"] res_status]
                    if {$res_status == "OK"} {

                        # the call to 'resource_check_parser' guarantees that
                        # in case of success the 3 list gids_l eids_l services_l
                        # are defined, at least as empty lists

                        lassign $parsed_results gids_l eids_l services_l
                        if {[llength $gids_l]} {
                            foreach gid $gids_l {

                                # ::ngis::service::service_data returns a *list* of service records
                                # even when this list is made of a single element

                                lappend services_l {*}[::ngis::service service_data $gid]
                            }
                        }
                        return [$formatter c116 $services_l]
                    } else {
                        lassign $parsed_results code a
                        return [$formatter c${code} $a]
                    }
                }
                QTASK {
                    # unlike QSERVICE command QTASK accepts only one argument
                    # and it must be the gid of the associated service
                    set parsed_results [lassign [my resource_check_parser $arguments "services"] res_status]
                    if {$res_status == "OK"} {

                        # after all for this command we are interested only in the gid value
                        # returned by resource_check_parser and we don't event consider the
                        # last 2 lists of parsed results

                        lassign $parsed_results gids_l
                        set services_l [::ngis::service service_data [lindex $gids_l 0]]
    
                        # ::ngis::service::service_data returns a *list* of service records
                        # even when this list is made of a single element. In this case
                        # we expect to get just one service record

                        return [$formatter c118 [lindex $services_l 0]]
                    } else {

                        # in case of error resource_check_parser may return a 109 error
                        # It's stored in the 'code' variable

                        lassign $parsed_results code a
                        return [$formatter c${code} $a]
                    }
                }
                FORMAT {
                    if {[string length $arguments] == 0} {
                        return [$formatter c104 [$formatter format]]
                    } else {
                        set fmt $arguments
                        switch -nocase $fmt {
                            HR   { set formatter $hr_formatter }
                            JSON { set formatter $json_formatter }
                            default {
                                return [$formatter c113 $fmt]
                            }
                        }
                        return [$formatter c104 [$formatter format]]
                    }
                }
                WHOS {
                    return [$formatter c112 [$::ngis_server whos]]
                }
                SET {

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

package provide ngis::protocol 1.1
