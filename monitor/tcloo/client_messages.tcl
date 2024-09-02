package require TclOO
package require yajltcl

catch { ::ngis::ClientMessages destroy }

oo::class create ngis::ClientMessages

oo::define ngis::ClientMessages {
    variable formatter
    variable CodeMessages
    variable json_o

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
                                      103     "Monitor is running"        \
                                      105     "Monitor Inconsistent status" \
                                      106     "%d running jobs\n%s" \
                                      501     "Server internal error: %s"]

        set formatter HR
        set json_o    ""
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
            007 {
                lassign $args ecode einfo
                $json_o string error_code string $ecode \
                        string error_info string $einfo \
                        string message    string [format $fstring $ecode ""]
            }
            009 -
            003 -
            001 {
                if {[llength $args] < 1} {
                    return -code error -errorcode missing_argument "missing argument for error code $code"
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
                            $json_o map_open string "object"      string      $s \
                                             string "description" string     [$s description] \
                                             string "active_jobs" integer    [$s active_jobs] \
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
                    return -code error -errorcode missing_argument "missing argument for error code $code"
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
                    set strmsg  "no running sequences ([llength $pending] pending)"
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
}

namespace eval ::ngis::ClientMessages {
    proc mkretcodes {} { return [::ngis::ClientMessages new] }
}

package provide ngis::clientmsg 1.0
