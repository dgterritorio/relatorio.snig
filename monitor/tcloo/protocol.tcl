package require TclOO
package require yajltcl

catch { ::ngis::Protocol destroy }

oo::class create ngis::Protocol

oo::define ngis::Protocol {
    variable formatter
    variable CodeMessages
    variable json_o
    variable ds_nseq
    variable nseq

    constructor {} {

        # output can take 3 values: HR (human readable), RAW (parseable row data), JSON

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
                                      106     "%d running jobs\n%s"         \
                                      501     "Server internal error: %s"   \
                                      503     "Missing argument for code %d"]

        set formatter HR
        set json_o    ""
        set nseq    -1
        set ds_nseq -1
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
            RAW -
            JSON {
                set formatter [string toupper $f]
            }
            default {
                return -code 1 "Invalid formatter: must be either HR, JSON or RAW"
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

    method JSON {code args} {
        set code_messages $CodeMessages
		if {[catch {set fstring [dict get $code_messages $code]}]} {
			return [my JSON 501 "undefined code $code"]
		}

        if {$json_o == ""} { set json_o [yajl create [namespace current]::json -beautify 1] }
        $json_o map_open string code string $code
        switch $code {
            000 {
                $json_o string message string [format $fstring] 
            }
            002 {
                $json string message string $fstring
            }
            102 {
                $json_o string format string [my format] \
                        string message string [format $fstring [my format]
            }
            007 {
                if {[llength $args] < 2} {
                    return [my JSON 503 $code]
                }
                lassign $args ecode einfo
                $json_o string error_code string $ecode \
                        string error_info string $einfo \
                        string message    string [format $fstring $ecode ""]
            }
            009 -
            003 -
            005 -
            001 {
                if {[llength $args] < 1} {
                    return [my JSON 503 $code]
                }
                lassign $args command_arg
                set strmsg [format $fstring $command_arg]
                $json_o string error_code string missing_argument \
                        string error_info string "" \
                        string message    string [format $fstring $command_arg]
            }
            104 {
                if {[llength $args] > 0} {
                    lassign $args current_format
                } else {
                    set current_format [my format]
                }
                $json_o string format  string $current_format \
                        string message string [format $fstring $current_format]
            }
            106 {
				set running [lindex $args 0]
                set pending [lindex $args 2]
                $json_o string message string "[llength $running] running, [llength $pending] sequences"
                foreach sclass [list pending running] {
                    if {[llength [set $sclass]] > 0} {
                        $json_o map_open string $sclass integer [llength [set $sclass]]
                        $json_o array_open
                        foreach s [set $sclass] {
                            $json_o map_open string "object"         string   $s \
                                             string "description"    string  [$s description] \
                                             string "active_jobs"    integer [$s active_jobs] \
                                             string "completed_jobs" integer [$s completed_jobs] \
                                    map_close     
                        }
                        $json_o array_close
                    }
                }
            }
            501 {
                $json_o string message string "Server internal error"
                $json_o array_open
                set n 0
                foreach a $args {
                    $json_o map_open string "argument [incr n]" string $a map_close
                }
                $json_o array_close
                #set strmsg [format $fstring [join $args "\n === \n"]] 
            }
            default {
                $json_o string message string [dict get $code_messages $code]
            }
        }
        $json_o map_close
        set json_txt [$json_o get]
        $json_o reset
        return $json_txt
    }


    method RAW {code args} {
        set code_messages $CodeMessages

        switch $code {
            007 {
                lassign $args ecode einfo
                return "($ecode) $einfo"
            }
            009 -
            003 -
            001 {
                return 0
            }
            106 {
				set seql [lindex $args 0]
                set pending [lindex $args 2]
                return [list $seql [llength $pending]]
            }
            501 {
                lassign $args ecode einfo
                return [join [list 501 $ecode $einfo] "\n"]
            }
            101 -
            102 -
            002 {
                return 1
            }
            default {
                return $code
            }
        }
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
            106 {
				set seql [lindex $args 0]
                set pending [lindex $args 2]
                if {[llength $seql] == 0} {
                    set strmsg  "no running sequences ([llength $pending] pending sequences)"
                } else {
                    set strmsg "[lindex $args 1] running jobs\n[llength $pending] pending sequences"
                    set seqs_l [lmap s $seql { format "\[106\] %s (%s active jobs)" [$s get_description] [$s active_jobs] }]
                    set strmsg [format $fstring [lindex $args 1] [join $seqs_l "\n"]]
                }
			}
            501 {
                set strmsg [format $fstring [join $args "\n === \n"]] 
            }
            default {
                set strmsg [dict get $code_messages $code]
            }
        }
        return [format "\[%s\] %s" $code $strmsg]
    }

    method compose {code args} { 
        return [eval my $formatter $code $args]
    }

    method parse_cmd {args} {

        set msg [string trim $args]
        puts "msg >$msg ([llength $msg])<"
        if {[regexp -nocase {^(\w+)\s*.*$} $msg m cmd] == 0} {
            return "001: unrecognized command '$msg'"
        } else {
            set arguments  [lrange $msg 1 end]
            set narguments [llength $arguments]
            #puts "arguments: '$arguments' ($narguments)"
            switch [string toupper $cmd] {
                CHECK {
                    if {$narguments < 1} {
                        return [my compose 003 $arguments]
						break
                    }

                    if {[catch {
	                    set service_check [lindex $arguments 0]
                        set job_controller [$::ngis_server get_job_controller]
						if {[string is integer $service_check]} {
							set service_d [::ngis::service load_by_gid $service_check]
							if {$service_d == ""} {
								return [my compose 005 $service_check]
							} else {
                                if {[dict exists $service_d record_description]} {
                                    set description [dict get $service_d record_description]
                                } elseif {[dict exists $service_d record_entity]} {
                                    set description [dict get $service_d record_entity]
                                } else {
                                    set description "Unnamed record (gid=$service_check)"
                                }

								$job_controller post_sequence [::ngis::JobSequence create ::ngis::seq[incr nseq] \
									[::ngis::PlainJobList create ::ngis::ds[incr ds_nseq] [list $service_d]] $description]

								set client_message [my compose 002]
							}
						} else {
							set entity $service_check
                            set limit 0
							::ngis::logger emit "CHECK arguments $arguments"
                            if {$narguments == 2} { 
                                set limit [lindex $arguments 1] 
                                if {!([string is integer $limit] && ($limit > 0))} {
                                    return [my compose 011]
                                    break
                                }
                            }
							set resultset [::ngis::service load_by_entity $entity -limit $limit -resultset]

							$job_controller post_sequence [::ngis::JobSequence create ::ngis::seq[incr nseq] \
														  [::ngis::DBJobSequence create ::ngis::ds[incr ds_nseq] $resultset] $entity]
							set client_message [my compose 002]
						}
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
                        return [my compose 106 {*}$jc_status]
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
                            RAW -
                            JSON -
                            HR {
                                my set_format [string toupper $fmt]
                                return [my compose 104 [my format]]
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
