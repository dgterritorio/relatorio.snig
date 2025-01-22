# ancillary_thread.tcl --
#
# this is the code to be run within the ancillary I/O thread.
#
# In the communication with the snig server we assume
# answers are to be valid JSON messages.
#
#

lappend auto_path ".."
package require ngis::conf
package require json
package require syslog

namespace eval ::ngis::ancillary {
    set connection          ""
    set connection_status   idle
    set data_buffer         ""
    set json_data           ""
    set socket_keepalive    10000; # socket keepalive rescheduling delay (msecs)

    proc socket_connect {} {
        global connection

        set connection [socket $::ngis::tcpaddr $::ngis::tcpport]
        chan event $connection readable [list ::ngis::ancillary::read_from_chan $connection]
    }

    proc close_connection {} {
        global connection

        chan close $connection
    }

    proc reset_connection {} {
        global connection

        set connection ""
    }

    proc log_msg {s} {
        syslog -ident snig -facility user info $s
    }

    # ChatGPT provided procedure

    proc isValidJSON {inputString parsed_data_v} {
        upvar 1 $parsed_data_v parsed_json

        # Try to parse the JSON string
        #puts "validating ->> $inputString"

        if {[catch {
            set parsed_json [::json::json2dict $inputString]
            set retvalue 1
        } e einfo]} {
            return 0
        }

        return $retvalue
    }

    proc read_data {con} {
        set answer ""
        while {![chan eof $con] && [chan gets $con l] > 0} { 
            #puts $l
            append answer $l
        }
        return $answer
    }

    proc get_status {} {
        global connection_status
        return $connection_status
    }

    proc set_status {new_status} {
        global connection_status
        set connection_status $new_status
    }

    proc get_data {} {
        global json_data

        set_status idle
        return $json_data
    }

    proc read_from_chan {con} {
        global data_buffer
        global json_data

        if {[chan eof $con]} {
            set_status eof
            reset_connection
            return
        }

        set cstatus [get_status]
        if {$cstatus != "wait" && $cstatus != "reading"} {
            chan gets $con l
            return
        }

        set_status "reading"

        chan gets $con l

        append data_buffer $l
        #puts "..> $data_buffer"

        if {[isValidJSON $data_buffer parsed_data]} {
            
            log_msg "Valid JSON received, setting thread status as 'data_ready'"
            set_status data_ready
            set json_data $data_buffer

        }
    }

    proc send_command {cmd} {
        global data_buffer
        global connection

        #log_msg "sending command '$cmd'"
        set data_buffer ""
        chan puts $connection $cmd
        chan flush $connection
        set_status wait
    }

    proc exit_thread {} {
        ::thread::release
    }

    namespace export *
    namespace ensemble create
}
package provide ngis::ancillary_io_thread 1.0
