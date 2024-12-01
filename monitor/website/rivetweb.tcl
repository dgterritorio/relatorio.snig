package require uri

::rivet::apache_log_error info "auto_path: $auto_path"

package require ngis::logger
package require ngis::configuration
package require ngis::roothandler
package require DIO 2.0
package require dio_Tdbc 2.0
package require ngis::protocol
package require ngis::conf
package require ngis::servicedb
package require Thread
package require ngis::ancillary_io_thread
package require json

::rivetweb::init Marshal top -nopkg

set snig_header [exec /usr/bin/figlet "S.N.I.G"]

::ngis::conf init

namespace eval ::ngis {
    variable registered_tasks
    variable cssprogressive

    # defining the production system cssprogressive counter

    set cssprogressive [::ngis::conf::readconf cssprogressive]

    # starting the ancillary thread

    namespace eval ancillary {
        variable thread_id

        set thread_id [::thread::create -joinable -preserved {
            lappend auto_path "."
            package require ngis::ancillary_io_thread

            ::ngis::ancillary::socket_connect
            ::thread::wait

            if {$connection != ""} { chan close $connection }
        }]

        ::thread::send $thread_id [list ::ngis::ancillary::send_command "FORMAT JSON"]
        set status ""
        set n 0
        while {($status != "data_ready") && [incr n]} {
            ::thread::send $thread_id [list ::ngis::ancillary::get_status] status
            after 100
            if {$n > 10} {
                ::rivet::apache_log_error err "ancillary thread timeout"
                break
            }
        }
        ::thread::send $thread_id [list ::ngis::ancillary::get_data] json_data
        set json_data [::json::json2dict $json_data]
        ::rivet::apache_log_error err "server responded with code [dict get $json_data code]"

        ::thread::send $thread_id [list ::ngis::ancillary::send_command "REGTASKS"]
        set status ""
        set n 0
        while {($status != "data_ready") && [incr n]} {
            ::thread::send $thread_id [list ::ngis::ancillary::get_status] status
            after 100
            if {$n > 10} {
                ::rivet::apache_log_error err "ancillary thread timeout"
                break
            }
        }
        ::thread::send $thread_id [list ::ngis::ancillary::get_data] json_data
        set json_data [::json::json2dict $json_data]
        ::rivet::apache_log_error err "server responded with code [dict get $json_data code]"

        if {[dict get $json_data code] == "110"} {
            set tasks_dl [dict get $json_data tasks]
            set ::ngis::registered_tasks [lmap t $tasks_dl {
                dict with t {
                    set task_v [list $task $function $description $procedure $script]
                }
                set task_v
            }]
        } else {
            set ::ngis::registered_tasks {}
            ::rivet::apache_log_error err "Could not load the registered tasks"
        }
    }
}


