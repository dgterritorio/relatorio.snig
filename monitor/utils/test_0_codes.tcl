#!/usr/bin/tclsh
#
# carefully and silently testing services that returned HTTP 0 codes
#

package require json

# assuming the monitor configuration is in the parent directory
set current_dir [file normalize [file join [file dirname [info script]] ..]]

cd $current_dir

set curr_dir_pos [lsearch $auto_path $current_dir]
if {$curr_dir_pos < 0} {
    set auto_path [concat $current_dir $auto_path]
} elseif {$current_dir_pos > 0} {
    set auto_path [concat $current_dir [lreplace $auto_path $current_dir_pos $current_dir_pos]]
}

package require syslog
package require unix_sockets
package require tdbc
package require tdbc::postgres
package require ngis::servicedb
package require ngis::conf


# drawing on Tclx too for its random number generator
#
package require Tclx

# basic stuff used by the asynchronous I/O procedures

set next_entity         0
set json_txt            ""
set expected_code       0
set protocol_status     OK
set returned_message_d  ""

proc reset_proto {code} {
    global json_txt
    global expected_code

    set expected_code $code
    set json_txt ""
}

proc socket_readable {con} {
    global expected_code
    global protocol_status
    global json_txt
    global returned_message_d

    if {[chan eof $con]} {
        puts "eof detected"
        chan close $con
        return
    }

    append json_txt [chan gets $con]

    if {[catch { set returned_message_d [::json::json2dict $json_txt] }]} {
        set protocol_status READING
        return
    }

    puts "returned code: [dict get $returned_message_d] (expected $expected_code)"

    if {[dict get $returned_message_d code] == $expected_code} {
        set protocol_status OK
    } else {
        set protocol_status [list [dict get $returned_message_d code] "protocol error"]
    }
    incr ::next_entity
}

proc send_to_server {connection client_message expcode {waittime 400}} {
    reset_proto $expcode
    chan puts $connection $client_message
    chan flush $connection
    after $waittime
}

random seed [clock seconds]

set con [unix_sockets::connect $::ngis::unix_socket_name]
chan event $con readable [namespace code [list socket_readable $con]]

send_to_server $con "FORMAT JSON" 104

vwait ::next_entity
lassign $protocol_status proto_status_code
if {$proto_status_code != "OK"} {
    syslog -perror -ident snig -facility user info "Protocol error $protocol_status"
    return
} else {
    puts "protocol format set as JSON"
}

append sql "select uri,ul.gid,description,ss.exit_info,ss.ts from testsuite.uris_long ul" " " \
           "join testsuite.service_status ss on ss.gid=ul.gid where ss.exit_info like 'Invalid% 0' order by ul.gid"

set resultset [::ngis::service exec_sql_query $sql]
#return
# setting up the random number generator

while {[$resultset nextdict service_d]} {
    dict with service_d {
        syslog -perror -ident snig -facility user info "check service with gid $gid ($description)"
        send_to_server $con "CHECK $gid" 102
        vwait ::next_entity

#
        lassign $protocol_status proto_status_code
        if {$protocol_status_code != "OK"} {
            syslog -perror -ident snig -facility user info "Error sending 'CHECK $gid' ($protocol_status)"
            break
        }
        set njobs 1
        while {$njobs > 0} {
            send_to_server $con "JOBLIST" 114 1000
            vwait ::next_entity
            lassign $protocol_status proto_status_code
            if {$protocol_status_code != "OK"} {
                syslog -perror -ident snig -facility user info "Unrecoverable error"
                exit
            }
            set njobs [dict get $returned_message_d njobs]
        }
    }

    # wait for min 100 ms, max 4 secs

    after [expr 100 + [random 1900]]
}
$resultset close
chan close $con
syslog -perror -ident snig -facility user info "Terminating task of controlling HTTP 0 status records"

