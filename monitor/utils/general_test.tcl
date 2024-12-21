#!/usr/bin/tclsh

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

set next_entity     0
set json_txt        ""
set expected_code   0
set protocol_status OK

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

    if {[chan eof $con]} {
        puts "eof detected"
        chan close $con
        return
    }

    append json_txt [chan gets $con]

    #puts $json_txt
    if {[catch { set msg_d [::json::json2dict $json_txt] }]} {
        set protocol_status READING
        return
    }

    puts "returned code: [dict get $msg_d]"
    puts "expected code: $expected_code"

    if {[dict get $msg_d code] == $expected_code} {
        set protocol_status OK
    } else {
        set protocol_status [list [dict get $msg_d code] "protocol error"]
    }
    incr ::next_entity
}

proc send_to_server {connection client_message expcode {waittime 400}} {
    reset_proto $expcode
    chan puts $connection $client_message
    chan flush $connection
    after $waittime
}

#set sql "select entity,count(ul.gid) cnt from testsuite.uris_long ul group by entity order by cnt asc"
set sql "select e.*,count(ul.gid) gidcnt from testsuite.entities e join testsuite.uris_long ul on ul.eid=e.eid group by e.eid order by gidcnt desc"
set resultset [::ngis::service exec_sql_query $sql]

set con [unix_sockets::connect $::ngis::unix_socket_name]
chan event $con readable [namespace code [list socket_readable $con]]


send_to_server $con "FORMAT JSON" 104

vwait ::next_entity
lassign $protocol_status proto_status_code
if {$proto_status_code != "OK"} {
    syslog -perror -ident snig -facility user info "Protocol error $protocol_status"
    return
}

set nentities 0
set entities [$resultset allrows -as dicts]
foreach ent $entities {

    set eid [dict get $ent eid]
    if {[dict exists $ent description]} {
        set entity [dict get $ent description]
    } else {
        set entity undefined
    }

    syslog -perror -ident snig -facility user info "sent request for $entity, waiting..."

    send_to_server $con "CHECK eid=$eid" 102 500

    vwait ::next_entity
    
    lassign $protocol_status proto_status_code
    if {$proto_status_code != "OK"} {
        syslog -perror -ident snig -facility user info "Protocol error $protocol_status"
    }

    incr nentities

    if {$nentities > 100} { break }
}
syslog -ident snig -facility user info "Sent request for checks of $nentities entities"
