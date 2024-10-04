#
#   -- 
#
#

package require syslog

package require uri
package require ngis::msglogger
package require ngis::task
package require -exact TclCurl 7.22.1
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
    
    proc run_bash {task_d} {
        set url [::ngis::tasks url $task_d]
        array set uri_a [::uri::split $url]
        set script [::ngis::tasks function $task_d]

        set tmpfile_root [file join $::ngis::data_root snig tmp [thread::id]]
        set uuid [::ngis::tasks uuid $task_d]
        set script_args [list   [::ngis::tasks gid $task_d] \
                                [::ngis::tasks url $task_d] \
                                $uuid                       \
                                [::ngis::tasks type $task_d] \
                                [::ngis::tasks version $task_d]]

        set uri_type [::ngis::tasks type $task_d]
        set uuid_space [file join $::ngis::data_root snig data $uri_type $uuid]

        set script_args [join $script_args |]
        set cmd "/bin/bash $script \"$script_args\" $tmpfile_root $uuid_space"
        ::ngis::logger emit "running command: $cmd"
        if {[catch {
            set script_results [exec -ignorestderr {*}$cmd 2> /dev/null]
        } e einfo]} {
            ::ngis::logger emit "bash script error: $e $einfo"
            return [::ngis::tasks::make_error_result $e $einfo ""]
        }
        #::ngis::logger emit "got [string length $script_results] characters"
        #return [::ngis::tasks::make_ok_result [string length $script_results]]
        return $script_results
    }

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

    proc data_congruence {task_d} {

        # TODO: this is not portable

        set job_d [dict get $task_d job]

        foreach p [list uri entity description] {
            switch $p {
                entity -
                description {
                    if {!([dict exists $job_d $p] && ([dict get $job_d $p] != ""))} {
                        return [::ngis::tasks::make_warning_result "undefined_$p" "" "Undefined description"]
                    }
                }
                uri {
                    if {!([dict exists $job_d $p] && ([dict get $job_d $p] != ""))} {
                        return [::ngis::tasks::make_error_result "missing_url" "" "Undefined url for gid [$job_d gid]"]
                    }
                }
            }
        }
        return [::ngis::tasks::make_ok_result ""]
    }

}
package provide ngis::procedures 0.2
