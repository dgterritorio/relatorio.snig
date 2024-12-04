# ancillary_io_init.tcl --
#
#
#

package require Thread
package require ngis::logger
package require ngis::ancillary_io_thread

namespace eval ::ngis::ancillary {

    variable thread_id

    proc thread_init {} {
        return [::thread::create -joinable -preserved {
            lappend auto_path "."
            package require ngis::ancillary_io_thread

            ::ngis::ancillary::socket_connect
            ::thread::wait

            if {$connection != ""} { chan close $connection }
        }]
    }

    proc send_command_and_wait {thread_id snig_command} {
        ::thread::send $thread_id [list ::ngis::ancillary::send_command $snig_command]
        set status ""
        set n 0
        while {($status != "data_ready") && [incr n]} {
            ::thread::send $thread_id [list ::ngis::ancillary::get_status] status
            after 100
            if {$n > 10} {
                ::ngis log "ancillary thread timeout" error
                return -code error -errorcode ancillary_thread_timeout "Timeout on sending command '$snig_command'"
            }
        }
        ::thread::send $thread_id [list ::ngis::ancillary::get_data] json_data

        return $json_data
    }


    proc connection_init {thread_id} {
        set json_data [send_command_and_wait $thread_id "FORMAT JSON"]

        set json_data [::json::json2dict $json_data]
        ::ngis::log "server responded with code [dict get $json_data code]" error

        set json_data [send_command_and_wait $thread_id "REGTASKS"]
        set json_data [::json::json2dict $json_data]
        set code [dict get $json_data code]
        ::ngis::log "server responded with code $code" error

        if {$code == "110"} {
            set tasks_dl [dict get $json_data tasks]
            return [lmap t $tasks_dl {
                dict with t {
                    set task_v [list $task $function $description $procedure $script]
                }
                set task_v
            }]
        } else {
            ::ngis::log "Could not load the registered tasks" error
        }
    }

}

package provide ngis::ancillary_io 1.0
