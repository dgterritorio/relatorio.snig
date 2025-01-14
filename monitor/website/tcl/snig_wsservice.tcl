package require rwwebservice

namespace eval ::rwpage {
    ::itcl::class SnigWebService {
        inherit RWWebService

        constructor {key} {RWWebService::constructor $key} {
        }

        protected method notify_error {ecode einfo} { }

        protected method wait_for_response {} {
            set time_out false
            set ret_status "waiting"
            while {$ret_status != "data_ready"} {
                ::thread::send $::ngis::ancillary::thread_id [list ::ngis::ancillary get_status] ret_status
                after 100

                if {[incr n] > 20} {
                    set time_out true
                    break
                }
            }
            return $time_out
        }

        public method webservice {language argsqs} {
            ::rivet::apache_log_error info "[$this info class]: $argsqs"
            set arguments {}
            if {[dict exists $argsqs cmd]} {
                set cmd [dict get $argsqs cmd]
                for {set i 1} {$i <= 10} {incr i} {
                    set argname "var${i}"

                    if {[dict exists $argsqs $argname]} {
                        lappend arguments [dict get $argsqs $argname]
                    } else {
                        break
                    }
                }
                set server_cmd [string trim [join [concat $cmd $arguments] " "]]

                ::rivet::apache_log_error info "[$this info class]: sending command '$server_cmd'"
                ::thread::send $::ngis::ancillary::thread_id [list ::ngis::ancillary send_command $server_cmd]
            }
        }

        public method prepare_output {json_data} {
            return $json_data
        }

        public method print_content {language args} {
            if {[$this wait_for_response]} {
                puts -nonewline {{ "code": "601", "message": "Timeout error" }}
                flush stdout
            } else {
                ::thread::send $::ngis::ancillary::thread_id [list ::ngis::ancillary get_data] json_data
                puts [$this prepare_output $json_data]
            }
        }
    }

}

package provide ngis::webservice 1.0
