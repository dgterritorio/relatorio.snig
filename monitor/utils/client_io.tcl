# client_io.tcl --
#
# base procedure for implementing client operations

package require json
package require syslog
package require unix_sockets
package require ngis::conf

namespace eval ::ngis::clientio {
    variable json_txt            ""
    variable expected_code       0
    variable protocol_status     INIT
    variable returned_message_d  ""
    variable wait_v

    variable connection

    proc reset_proto {code} {
        variable json_txt
        variable expected_code
        variable protocol_status
        variable wait_v

        set protocol_status READING
        set expected_code $code
        set json_txt ""
        set wait_v  0
    }

    proc open_connection {{usocket ""}} {
        variable connection
        if {$usocket == ""} {
            set usocket $::ngis::unix_socket_name
        }
        set con [unix_sockets::connect $::ngis::unix_socket_name]
        chan event $con readable [namespace code [list [namespace current]::socket_readable $con]]
        set connection $con
        return $connection
    }
    namespace export open_connection

    proc set_protocol_status {new_st} {
        variable protocol_status
        variable wait_v

        set protocol_status $new_st
        incr wait_v
    }

    proc socket_readable {con} {
        variable expected_code
        variable protocol_status
        variable json_txt
        variable returned_message_d

        if {[chan eof $con]} {
            puts "eof detected"
            chan close $con
            return
        }

        append json_txt [chan gets $con]

        if {[catch { set returned_message_d [::json::json2dict $json_txt] }]} {
            set_protocol_status READING
            return
        }

        #puts "returned code: $returned_message_d (expected $expected_code)"

        if {[dict get $returned_message_d code] == $expected_code} {
            set_protocol_status OK
        } else {
            set_protocol_status [list [dict get $returned_message_d code] "protocol error"]
        }
    }

    proc send_to_server {connection client_message expcode {waittime 400}} {
        reset_proto $expcode
        chan puts $connection $client_message
        chan flush $connection
        after $waittime
    }
    namespace export send_to_server

    proc read_protocol_status {} {
        variable protocol_status

        return $protocol_status
    }
    namespace export read_protocol_status

    proc read_result_code {} {
        variable returned_message_d

        if {[dict exists $returned_message_d code]} {
            return [dict get $returned_message_d code]
        }

        return ""
    }
    namespace export read_result_code

    proc read_result {} {
        variable returned_message_d

        return $returned_message_d
    }
    namespace export read_result

    proc query_server {connection client_message expected_code {max_wait 40}} {
        variable wait_v

        send_to_server $connection $client_message $expected_code
        set proto_status [read_protocol_status]

	    set nwait_t [clock seconds]
        while {($proto_status == "READING") && ([expr [clock seconds] - $nwait_t] < $max_wait)} {
            #puts $proto_status
            vwait [namespace current]::wait_v 
            set proto_status [read_protocol_status]
        }
        
        if {$proto_status == "READING"} {
            return -code error -errorcode max_wait_timeout_error "Max $max_wait seconds timeout while reading from socket"
        }

        return [read_result]
    }
    namespace export query_server
    namespace ensemble create
}

package provide ngis::clientio 1.0
