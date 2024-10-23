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

    constructor {} {
        set hr_formatter    [::ngis::HRFormat create [::ngis::Formatters new_cmd hr]]
        set json_formatter  [::ngis::JsonFormat create [::ngis::Formatters new_cmd json]]

        # setting the default
        set formatter $hr_formatter
    }

    destructor {
    }

    method format {} { return $formatter }

    method set_format {f} {
        switch -nocase $f {
            HR {
                set formatter   $hr_formatter
            }
            JSON {
                set formatter   $json_formatter
            }
            default {
                return -code 1 "Invalid formatter: must be either HR or JSON"
            }
        }
    }

    method compose {code args} {
        return [eval $formatter c${code} {*}$args]
    }

    method parse_cmd {args} {
        set msg [string trim $args]
        puts "msg >$msg ([llength $msg])<"
        if {[regexp -nocase {^(\w+)\s*.*$} $msg m cmd] == 0} {
            return "001: unrecognized command '$msg'"
        } else {
            set arguments  [lrange $msg 1 end]
            set narguments [llength $arguments]
            puts "arguments: '$arguments' ($narguments)"
            switch [string toupper $cmd] {
                REGTASKS {
                    return [my compose 110 [::ngis::tasks list_registered_tasks]]
                }
                ENTITIES {
                    if {[llength $arguments] == 0} { set arguments "%" }
                    return [my compose 108 [::ngis::service::list_entities $arguments]]
                }
                CHECK {
                    if {$narguments < 1} {
                        return [my compose 003 $arguments]
						break
                    }

                    # checking the specific case of a sequence of gids
                    # (handy to handle forms submit build with checkboxes)

                    set integer_set false
                    if {$narguments > 1} {
                        set integer_set true
                        foreach a $arguments {
                            if {![string is integer $a]} {
                                set integer_set false
                                break
                            }
                        }
                    }

                    if {[catch {
                        set job_controller [$::ngis_server get_job_controller]
                        if {$integer_set} {
                            set service_l [::ngis::service load_series_by_gids $arguments]
                            if {[llength $service_l]} {
                                $job_controller post_sequence [::ngis::JobSequence create [::ngis::Sequences new_cmd]   \
                                                [::ngis::PlainJobList create [::ngis::DataSources new_cmd] $service_l]  \
                                                "series of [llength $service_l] gids"]
                            } else {
                                return [my compose 005 $service_check]
                            }
                        } else {
                            foreach service_check $arguments {
                                if {[string is integer $service_check]} {
                                    set service_d [::ngis::service load_by_gid $service_check]
                                    if {$service_d == ""} {
                                        return [my compose 005 $service_check]
                                    } else {
                                        if {[dict exists $service_d description]} {
                                            set description [dict get $service_d description]
                                        } elseif {[dict exists $service_d entity]} {
                                            set description [dict get $service_d entity]
                                        } else {
                                            set description "Unnamed record (gid=$service_check)"
                                        }

                                        $job_controller post_sequence [::ngis::JobSequence create [::ngis::Sequences new_cmd] \
                                                [::ngis::PlainJobList create [::ngis::DataSources new_cmd] [list $service_d]] $description]

                                    }
                                } else {
                                    set entity $service_check
                                    set resultset [::ngis::service load_by_entity $entity -resultset]

                                    $job_controller post_sequence [::ngis::JobSequence create [::ngis::Sequences get_cmd] \
                                                [::ngis::DBJobSequence create [::ngis::DataSources get_cmd] $resultset] $entity]
                                }
                            }
                        }
                        set client_message [my compose 002]
					} e einfo]} {
						return -code ok [my compose 007 $e $einfo]
					}
                    return $client_message
                }
                STOP {
                    [$::ngis_server get_job_controller] stop_operations
                    return [my compose 102]
                }
                QUERY {
                    if {$narguments == 0} {
						set jc_status [[$::ngis_server get_job_controller] status]
						set tm_status [[$::ngis_server get_job_controller] status "thread_master"]
                        return [my compose 106 $jc_status $tm_status]
                    } else {
						return [my compose 009 "[string toupper $cmd] $arguments"]
					}
                }
                FORMAT {
                    if {$narguments == 0} {
                        return [my compose 104 [my format]]
                    } elseif {$narguments == 1} {
                        set fmt [lindex $arguments 0]
                        switch -nocase $fmt {
                            JSON { set formatter $hr_formatter }
                            HR { set formatter $json_formatter }
                            default {
                                return [my compose 001 $msg]
                            }
                        }
                        return [$formatter c104]
                    } else {
                        return [my compose 003 $arguments]
                    }
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
