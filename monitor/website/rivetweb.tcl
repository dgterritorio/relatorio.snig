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

::rivetweb::init Marshal top -nopkg

set snig_header [exec /usr/bin/figlet "S.N.I.G"]

::ngis::conf init

namespace eval ::ngis {
    variable registered_tasks
    variable ancillary_thread

    set ancillary_thread [::thread::create -joinable -preserved {
        lappend auto_path "."
        package require ngis::ancillary_io_thread

        set connection [socket $::ngis::tcpaddr $::ngis::tcpport]
        chan event $connection readable [list read_from_chan $connection]

        ::thread::wait

        chan close $connection
    }]

    ::thread::send $::ngis::ancillary_thread [list send_command "FORMAT JSON"]
    set status ""
    set n 0
    while {($status != "data_ready") && [incr n]} {
        ::thread::send $::ngis::ancillary_thread [list get_status] status
        after 100
        if {$n > 10} {
            ::rivet::apache_log_error err "ancillary thread timeout"
            break
        }
    }
    ::thread::send $::ngis::ancillary_thread [list get_data] json_data
    ::rivet::apache_log_error err "server responded with code [dict get $json_data code]"

    ::thread::send $::ngis::ancillary_thread [list send_command "REGTASKS"]
    set status ""
    set n 0
    while {($status != "data_ready") && [incr n]} {
        ::thread::send $::ngis::ancillary_thread [list get_status] status
        after 100
        if {$n > 10} {
            ::rivet::apache_log_error err "ancillary thread timeout"
            break
        }
    }
    ::thread::send $::ngis::ancillary_thread [list get_data] json_data
    ::rivet::apache_log_error err "server responded with code [dict get $json_data code]"

    if {[dict get $json_data code] == "110"} {
        set tasks_dl [dict get $json_data tasks]
        set registered_tasks [lmap t $tasks_dl {
            dict with t {
                set task_v [list $task $function $description $procedure $script]
            }
            set task_v
        }]
    } else {
        set registered_tasks {}
        ::rivet::apache_log_error err "Could not load the registered tasks"
    }
}
