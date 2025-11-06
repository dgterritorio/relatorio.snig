#
#   -- 
#
#

package require syslog

package require uri
package require ngis::msglogger
package require ngis::task
package require TclCurl
package require ngis::taskmessages

namespace eval ::ngis::procedures {
    variable http_data

    # --

    proc null_processing {task_d} {
        set jobname  [::ngis::task job_name $task_d]
        set url      [::ngis::task url $task_d]
        after 1000
        #return [list $jobname ok "" "" $url]
        return [::ngis::tasks::make_ok_result "($jobname) $url"]
    }

    proc start {task_d} {
        return [::ngis::tasks::make_ok_result ""]
    }

    # --

    proc run_ping {task_d} {
        set url [::ngis::tasks url $task_d]
        array set uri_a [::uri::split $url]
        ::ngis::logger emit "checking $url ping service"
        set cmd [list ping -W 20 -w 20 -c 2 -a $uri_a(host)]
        ::ngis::logger emit "executing '$cmd'"
        if {[catch { 
            set ping_results [exec {*}$cmd] 
        } e einfo]} {
            #return [list $jobname error $e $einfo ""]
            return [::ngis::tasks::make_error_result $e $einfo ""]
        }
        return [::ngis::tasks::make_ok_result $ping_results]
    }

    proc get_url {task_d} {
        set url [::ngis::tasks url $task_d]
        if {[catch {

            ::ngis::logger emit "getting $url"
            #::http::geturl $url -command url_cb
            set tk [::http::geturl $url]
            set http_returned_data [::http::data $tk]
            ::ngis::logger emit "get_url: got [string length $http_returned_data] bytes from $url"

        } e einfo]} {
            #return [list $jobname error $e $einfo ""]
            return [::ngis::tasks::make_error_result $e $einfo ""]
        }
        return [::ngis::tasks::make_ok_result "[string length $http_returned_data] characters returned"]
    }
    
    proc format_elapsed_time {et} {
        return [format "%.3f" [expr double($et)/1000.]]
    }

    proc run_tcl {task_d} {

        set script [::ngis::tasks script $task_d]
        set tcl_proc [::ngis::tasks function $task_d]
        if {[info command $tcl_proc] == ""} {
            namespace eval ::ngis::tasks [list source $script]
        }

		set gid      [::ngis::tasks gid $task_d]
        set uri_type [::ngis::tasks type $task_d]
        set uuid     [::ngis::tasks uuid $task_d]
        set function [::ngis::tasks function $task_d]

        set uuid_space      [file join $::ngis::data_root data $uri_type $uuid $gid]
        set tmpfile_root    [file join $::ngis::data_root tmp [thread::id]]
        if {[ catch {
            set t1 [clock milliseconds]
            set script_results [::ngis::tasks::${function} $task_d $tmpfile_root $uuid_space]
            set t2 [clock milliseconds]
            lappend script_results [format_elapsed_time [expr $t2 - $t1]]
        } e einfo] } {
            ::ngis::logger emit "Tcl script error: $e $einfo"
            return [::ngis::tasks::make_error_result $e $einfo ""]
        }

        return $script_results
    }

    proc bash_script_args {task_d} {
        set script_args [list   [::ngis::tasks gid $task_d]     \
                                [::ngis::tasks url $task_d]     \
                                [::ngis::tasks uuid $task_d]    \
                                [::ngis::tasks type $task_d]    \
                                [::ngis::tasks version $task_d]]

        set script_args [join $script_args |]
        return $script_args
    }

    proc run_bash {task_d} {
        # The task arguments are composed into a "|" separated string
        set script_args [bash_script_args $task_d]

        # determine the storage space for this task. The uuid_space and
        # tmpfile_root directory are passed as arguments to the script.

		set gid			 [::ngis::tasks gid $task_d]
        set uuid         [::ngis::tasks uuid $task_d]
        set uri_type     [::ngis::tasks type $task_d]
        set uuid_space   [file join $::ngis::data_root data $uri_type $uuid $gid]
        set tmpfile_root [file join $::ngis::data_root tmp [thread::id]]

        set script [::ngis::tasks script $task_d]
        set cmd [list /usr/bin/timeout "${::ngis::task_timeout}s" /bin/bash $script "$script_args" $tmpfile_root $uuid_space]
        ::ngis::logger debug "running command: [join $cmd " "]"

        try {

            set t1 [clock milliseconds]
            set script_results [exec -ignorestderr {*}$cmd 2> /dev/null]
            set t2 [clock milliseconds]
            lappend script_results [format_elapsed_time [expr $t2 - $t1]]

        } trap CHILDSTATUS {results options} {
            set status [lindex [dict get $options -errorcode] 2]
            switch $status {
                124 {
                    set script_results [::ngis::tasks::make_error_result task_timeout \
                                                "task execution times out after $::ngis::task_timeout secs" "task_timeout"]
                    lappend script_results $::ngis::task_timeout
                }
                default {
                    set script_results [::ngis::tasks::task_execution_error task_error \
                                                "Task execution failed" [dict get $options -errorcode]]
                    lappend script_results 0
                }
            }
        } on error {e options} {
            ::ngis::logger emit "bash script error: $e $options"
            return -options $options -level 0 $e
        }

        return $script_results
    }

    # append_http_data --
    #
    # Ancillary procedure of http_status. It provides a callback
    # to tclcurl that stores in a buffer the data returned by the remote peer

    proc append_http_data {http_data} {
        append ::ngis::procedures::http_data $http_data
    }

    proc http_status {task_d} {
        set url [::ngis::tasks url $task_d]

        ::ngis::logger emit "http_status: checking HTTP response from $url"

        set curl [::curl::init]
        $curl configure -url $url -header 1 -timeout 5000 -writeproc [namespace current]::append_http_data

        set curl_code       [$curl perform]
        set connect_time    [$curl getinfo connecttime]
        set response_code   [$curl getinfo responsecode]

        switch $curl_code {
            0 {
                set status [::ngis::tasks::make_ok_result "connect time $connect_time http code $response_code"]
            }
            3 {
                set status [::ngis::tasks::make_error_result "malformed_url" "tclcurl error" "malformed URL"]
            }
            7 {
                set status [::ngis::tasks::make_error_result "connection failed" "tclcurl error" "Connection failed"]
            }
            default {
                set status [::ngis::tasks::make_error_result "tclcurl_error" "" "curl perform exit code = $curl_code"]
            }
        }
        $curl cleanup
        return $status
    }

}
package provide ngis::procedures 0.2
