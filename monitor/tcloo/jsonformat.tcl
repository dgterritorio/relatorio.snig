# -- jsonformat.tcl
#
#

package require yajltcl
package require ngis::common

oo::class create ngis::JsonFormat

oo::define ngis::JsonFormat {
    variable json_o

    constructor {} {
        set json_o ""
    }

    destructor {
        # destroy $json_o
    }

    method format {} { return "JSON" }

    method unknown {target args} {
        # extract the code from the target name
        scan $target "c%s" code
        if {[regexp {c(\d+)} $target -> code] == 0} {
            return -code error -errorcode invalid_target -errorinfo "Error target $target"
        }

        if {[info commands $json_o] != ""} { $json_o delete }
        set json_o [yajl create [namespace current]::json -beautify 1]
        $json_o map_open string code string $code
        #puts [list $json_o map_open string code string $code]

		if {[catch {set fstring [::ngis::protocol::get_fmt_string $code]} e einfo]} {
			set json_txt [my JSON 501 "undefined code $code"]
		} else {
            my JSON $code $fstring {*}$args
        }

        $json_o map_close
        set json_txt [$json_o get]
        $json_o delete
        set json_o ""
        return $json_txt
    }

    method JSON {code fstring args} {
        puts "JSON >$code< >$fstring< >$args<"
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
                    return [my HR 503 $code]
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
                lindex $args running njobs pending
                $json_o string message string "[llength $running] job sequences ($njobs jobs), [llength $pending] sequences"
                foreach sclass [list pending running] {
                    if {[llength [set $sclass]] > 0} {
                        $json_o map_open string $sclass integer [llength [set $sclass]]
                        $json_o array_open
                        foreach s [set $sclass] {
                            $json_o map_open string "object"         string   $s \
                                             string "description"    string  [$s description] \
                                             string "active_jobs"    integer [$s active_jobs_count] \
                                             string "completed_jobs" integer [$s completed_jobs] \
                                    map_close     
                        }
                        $json_o array_close
                    }
                }
            }
            108 {
                set entities [lindex $args 0]
                $json_o string entities array_open
                foreach e $entities {
                    lassign $e eid description
                    $json_o map_open string "eid" integer $eid string description string $description map_close
                }
                $json_o array_close
            }
            110 {
                set tasks [lindex $args 0]
                $json_o string tasks array_open
                foreach t $tasks {
                    lassign $t  task func desc pro script
                    $json_o map_open string "task" string $task \
                                     string "script" string $script \
                                     string "function" string $func \
                                     string "description" string $desc \
                                     string "procedure" string $pro map_close
                }
                $json_o array_close
            }
            501 {
                $json_o string message string "Server internal error"
                if {[llength $args] > 0} {
                    $json_o array_open
                    set n 0
                    foreach a $args {
                        $json_o map_open string "argument [incr n]" string $a map_close
                    }
                    $json_o array_close
                }
            }
            default {
                $json_o string message string [dict get $code_messages $code]
            }
        }
    }

}
package provide ngis::jsonformat 0.1
