#
#   -- 
#
#

package require syslog

package require uri
package require ngis::msglogger
package require -exact TclCurl 7.22.1
package require ngis::taskmessages

namespace eval ::ngis::procedures {
    variable http_data

    # --

    proc null_processing {job f} {
        set jobname  [dict get $job jobname]
        set url      [dict get $job uri]
        after 1000
        #return [list $jobname ok "" "" $url]
        return [::ngis::tasks::make_ok_result $jobname $url]
    }

    proc start {job function} {
        return [::ngis::tasks::make_ok_result ""]
    }

    # --

    proc run_ping {job function} {
        set url [dict get $job uri]
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

    proc get_url {job f} {
        set url [dict get $job uri]
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
    

    proc run_bash {url function} {
        array set uri_a [::uri::split $url]
        set script $function
        set cmd "/bin/bash [file join tasks "${script}.sh"] \"$url\""
        ::ngis::logger emit "running command: $cmd"
        if {[catch {
            set script_results [exec -ignorestderr {*}$cmd 2> /dev/null]
        } e einfo]} {
            ::ngis::logger emit "error: $e $einfo"
            return [::ngis::tasks::make_error_result $e $einfo ""]
        }
        ::ngis::logger emit "got [string length $script_results] characters"
        return [::ngis::tasks::make_ok_result [string length $script_results]]
    }

    proc append_http_data {http_data} {
        append ::ngis::procedures::http_data $http_data
    }

    proc http_status {job f} {
        set url [dict get $job uri]

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

    proc data_congruence {job_d f} {
        foreach p [list uri record_entity record_description] {
            switch $p {
                record_entity -
                record_description {
                    if {!([dict exists $job_d $p] && ([dict get $job_d $p] != ""))} {
                        return [::ngis::tasks::make_warning_result "undefined_$p" "" "Undefined description"]
                    }
                }
                uri {
                    if {!([dict exists $job_d $p] && ([dict get $job_d $p] != ""))} {
                        return [::ngis::tasks::make_error_result "missing_url" "" "Undefined url for gid [$job_o gid]"]
                    }
                }
            }
        }
        return [::ngis::tasks::make_ok_result ""]
    }

}
package provide ngis::procedures 0.2
