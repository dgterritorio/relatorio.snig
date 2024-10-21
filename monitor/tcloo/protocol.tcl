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
    variable json_o
    variable ds_nseq
    variable nseq
    variable hr_formatter

    constructor {} {

        # output can take 2 values: HR (human readable), JSON

        set output_format "HR"
        set CodeMessages [dict create 000     "Server is going to exit"   \
                                      102     "Current data format: %s"   \
                                      001     "Unrecognized command: %s"  \
                                      002     "OK"                        \
                                      003     "Wrong arguments: %s"       \
                                      005     "Invalid service gid: %d"   \
                                      007     "Error in query: (%s) %s"   \
                                      009     "Command %s disabled"       \
                                      011     "Invalid limit on query"    \
                                      100     "Starting server"           \
                                      102     "Stopping operations"       \
                                      104     "current format %s"         \
                                      105     "Monitor Inconsistent Status" \
                                      106     "%s queued, %s pending sequences, %d jobs" \
                                      108     "%d matching entities\n%s"    \
                                      110     "%d registered tasks\n%s"     \
                                      501     "Server internal error: %s"   \
                                      503     "Missing argument for code %d"]

        set json_o    ""
        set nseq    -1
        set ds_nseq -1

        set hr_formatter [::ngis::HRFormat create [::ngis::Formatter new_cmd hr]]
        set json_formatter [::ngis::JsonFormat create [::ngis::Formatter new_cmd json]]

        # setting the default
        set formatter $hr_formatter
    }

    destructor {
        if {$json_o != ""} {
            $json_o delete
        }
    }

    method format {} { return $formatter }

    method set_format {f} {
        switch -nocase $f {
            HR -
            JSON {
                set formatter [string toupper $f]
            }
            default {
                return -code 1 "Invalid formatter: must be either HR or JSON"
            }
        }
    }

    method catalog {} {
        set msg {}
        dict for {code message} $CodeMessages {
            lappend msg "$code: $message"
        }
        return [join $msg "\n"]
    }

    method HR {code args} {
        set code_messages $CodeMessages
		if {[catch {set fstring [dict get $code_messages $code]}]} {
			return [my HR 501 "undefined code $code"]
		}
			
        switch $code {
            007 {
                lassign $args ecode einfo
                set strmsg [format $fstring $ecode $einfo] 
            }
            009 -
            003 -
            001 {
                if {[llength $args] < 1} {
                    return [my JSON 503 $code]
                }
                lassign $args command_arg
                set strmsg [format $fstring $command_arg]
            }
            104 {
                if {[llength $args] > 0} {
                    lassign $args current_format
                } else {
                    set current_format [my format]
                }
                set strmsg [format $fstring $current_format]
            }
            002 {
                return [$formatter c002]
            }
            106 {
                lassign $args jc_status tm_status

                lassign $jc_status queued njobs pending
                lassign $tm_status nrthreads nithreads

                set jobs_l {}
                if {[llength $queued] > 0} {
                    set jobs_l [lmap s $queued { list $s [$s get_description] [$s active_jobs_count] "queued" }]
                }
                if {[llength $pending] > 0} {
                    set pending_l [lmap s $pending { list $s [$s get_description] [$s active_jobs_count] "pending" }]
                    set jobs_l [concat $jobs_l $pending_l]
                }

                return [$formatter c106 $jobs_l $tm_status]
			}
            108 {
                set entities [lindex $args 0]

                set gid_l 1
                foreach e $entities {
                    lassign $e gid definition
                    set gid_l [expr max([string length $gid]+1,$gid_l)]
                }
                set table ""
                foreach e $entities {
                    lassign $e gid definition
                    lappend table [format "%-${gid_l}d %s" $gid $definition]
                }
                set table [join $table "\n"]
                set strmsg [format $fstring [llength $entities] $table]
            }
            110 {
                return [$formatter c110 [lindex $args 0]]
            }
            501 {
                set strmsg [format $fstring [join $args "\n === \n"]] 
            }
            default {
                #set strmsg [dict get $code_messages $code]
                return [$formatter single_line $code] 
            }
        }
        return [format "\[%s\] %s" $code $strmsg]
    }

    method compose {code args} { 
        return [eval $formatter $code {*}$args]
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
                                $job_controller post_sequence [::ngis::JobSequence create ::ngis::seq[incr nseq] \
                                    [::ngis::PlainJobList create ::ngis::ds[incr ds_nseq] $service_l] "series of [llength $service_l] gids"]
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

                                        $job_controller post_sequence [::ngis::JobSequence create ::ngis::seq[incr nseq] \
                                        [::ngis::PlainJobList create ::ngis::ds[incr ds_nseq] [list $service_d]] $description]

                                        #set client_message [my compose 002]
                                    }
                                } else {
                                    set entity $service_check
                                    set resultset [::ngis::service load_by_entity $entity -resultset]

                                    $job_controller post_sequence [::ngis::JobSequence create ::ngis::seq[incr nseq] \
                                                                  [::ngis::DBJobSequence create ::ngis::ds[incr ds_nseq] $resultset] $entity]
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
                            JSON -
                            HR {
                                my set_format [string toupper $fmt]
                                return [$formatter c104]
                            }
                            default {
                                return [my compose 001 $msg]
                            }
                        }
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
