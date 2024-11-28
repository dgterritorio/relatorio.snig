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
        # 
        if {[regexp {c(\d+)} $target -> code] == 0} {
            return -code error -errorcode invalid_target -errorinfo "Error: unknown target '$target'"
        }

        if {[info commands $json_o] != ""} { $json_o delete }
        set json_o [yajl create [namespace current]::json -beautify 1]
        $json_o map_open string code string $code
        #puts [list $json_o map_open string code string $code]

		if {[catch {set fstring [::ngis::reports::get_fmt_string $code]} e einfo]} {
			set json_txt [my JSON 501 "undefined code $code"]
		} else {
            my JSON $code $fstring {*}$args
        }

        $json_o map_close
        set json_txt [$json_o get]
        $json_o delete

        return $json_txt
    }

    method JSON {code fstring args} {
        #puts "JSON >$code< >$fstring< >$args<"
        switch $code {
            100 -
            105 -
            102 -
            120 {
                $json_o string message string $fstring
            }
            101 -
            103 -
            109 {
                if {[llength $args] < 1} {
                    return [my JSON 503 $code]
                }
                lassign $args first_argument
                set strmsg [format $fstring $first_argument]
                $json_o string error_code string missing_argument \
                        string error_info string "" \
                        string message    string $strmsg
            }
            107 {
                if {[llength $args] < 2} {
                    return [my JSON 503 $code]
                }
                lassign $args ecode einfo
                $json_o string status     string error  \
                        string error_code string $ecode \
                        string error_info string $einfo \
                        string message    string [format $fstring $ecode ""]
            }
            113 {
                lassign $args ecode
                $json_o string status     string error \
                        string error_code string invalid_format \
                        string message    string [format $fstring $ecode ""]
            }
            104 {
                if {[llength $args] > 0} {
                    lassign $args current_format
                } else {
                    set current_format [my format]
                }
                $json_o string status   string ok \
                        string format   string $current_format \
                        string message  string [format $fstring $current_format]
            }
            106 {
                lassign $args jc_status tm_status
                lassign $jc_status queued njobs pending
                lassign $tm_status nrthreads nithreads
                $json_o string status   string ok \
                        string message  string "[llength $queued] queued job sequences ($njobs jobs), [llength $pending] pending sequences" \
                        string threads  map_open string running integer $nrthreads string idle integer $nithreads map_close
            
                foreach sclass [list pending queued] {
                    if {[llength [set $sclass]] > 0} {
                        $json_o string $sclass array_open

                        puts "$sclass: [set $sclass]"

                        foreach s [set $sclass] {
                            $json_o map_open string "sequence"          string  $s \
                                             string "description"       string  [$s get_description]   \
                                             string "active_jobs"       integer [$s active_jobs_count] \
                                             string "completed_jobs"    integer [$s completed_jobs]    \
                                             string "total_jobs_number" integer [$s njobs] \
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
                    lassign $e eid description nrecs
                    $json_o map_open string "eid"     integer $eid   string description string $description \
                                     string "records" integer $nrecs map_close
                }
                $json_o array_close
            }
            110 {
                set tasks [lindex $args 0]
                $json_o string tasks array_open
                foreach t $tasks {
                    lassign $t task func desc pro script
                    $json_o map_open string "task"          string $task \
                                     string "script"        string $script \
                                     string "function"      string $func \
                                     string "description"   string $desc \
                                     string "procedure"     string $pro map_close
                }
                $json_o array_close
            }
            112 {
                set whos_l [lindex $args 0]
                $json_o string nconnections integer [llength $whos_l]

                # if we're here there must be at least one connection active
                # we don't need to check [llength $whos_l]

                $json_o string connections array_open
                foreach c $whos_l {
                    lassign $c login type ncmds protocol idle_time_s
                    $json_o map_open    string "login"      string $login   \
                                        string "type"       string $type    \
                                        string "ncmds"      string $ncmds   \
                                        string "protocol"   string $protocol \
                                        string "idle"       string $idle_time_s map_close
                }
                $json_o array_close
            }
            114 {
                set jobs_l [lindex $args 0]
                $json_o string njobs integer [llength $jobs_l]

                if {[llength $jobs_l] > 0} {
                    $json_o string jobs array_open
                    foreach jl $jobs_l {
                        lassign $jl gid descr uri_type version job_status timestamp
                        $json_o map_open    string "gid"            integer $gid        \
                                            string "description"    string $descr       \
                                            string "type"           string $uri_type    \
                                            string "version"        string $version     \
                                            string "status"         string $job_status  \
                                            string "timestamp"      integer $timestamp map_close
                    }
                    $json_o array_close
                }
            }
            116 {
                set services_l [lindex $args 0]
                $json_o string message string [format $fstring [llength $services_l]]
                if {[llength $services_l] > 0} {
                    $json_o string services array_open
                    foreach s $services_l {

                        dict with s {
                            $json_o map_open    string "gid"    integer $gid    \
                                                string "description" string $description \
                                                string "entity"     string  $entity_definition \
                                                string "uri"        string  $uri    \
                                                string "uri_type"   string  $uri_type \
                                                string "version"    string $version \
                                                string "uuid"       string  $uuid
                        }
                        set tasks [dict get $s tasks]
                        $json_o string "tasks" array_open
                        dict for {task task_d} $tasks {
                            $json_o map_open string "task" string $task 
                            dict with task_d {
                              $json_o   string "timestamp"  string $ts  \
                                        string "status"     string $exit_status \
                                        string "info"       string $exit_info   \
                                        string "uuid"       string $uuid
                            }
                            $json_o map_close
                        }
                        $json_o array_close map_close
                    }
                    $json_o array_close
                }
            }
            118 {
                set service_d [lindex $args 0]
                dict with service_d {
                    $json_o string message string [format $fstring $gid $description $uri_type]
                    $json_o string tasks array_open

                    #puts "..........\n$tasks\n........."

                    if {[info exists tasks]} {
                        foreach t [::ngis::tasks::list_registered_tasks] {
                            lassign $t task procedure tdescr filename language

                            if {[dict exists $tasks $task]} {
                                set tasks_data [dict get $tasks $task]
                                $json_o map_open string "task" string $task
                                foreach k {exit_status exit_info ts} {
                                    $json_o string $k string [dict get $tasks_data $k]
                                }
                                $json_o map_close
                            } else {
                                continue
                            } 
                        }
                    }
                    $json_o array_close
                }
            }
            122 {
                set services_l [lindex $args 0]
                $json_o string message string $fstring
                $json_o string services array_open
                foreach s $services_l {
                    dict with s {
                        $json_o map_open string gid integer $gid
                        $json_o string description string $description
                        $json_o string host string [dict get [::uri::split $uri] host]
                        $json_o string type string $uri_type
                        $json_o string version string $version map_close
                    }
                }
                $json_o array_close
            }
            501 {
                $json_o string message string "Server internal error"
                if {[llength $args] > 0} {
                    $json_o string breakdown array_open
                    set n 0
                    foreach a $args {
                        $json_o map_open string "argument [incr n]" string $a map_close
                    }
                    $json_o array_close
                }
            }
            502 {
                $json_o string status       string ok \
                        string message      string $fstring
            }
            503 {
                $json_o string message string [format $fstring [lindex $args 0]]
            }
            default {
                $json_o string message string "Unmapped message"
            }
        }
    }

}
package provide ngis::jsonformat 0.1
