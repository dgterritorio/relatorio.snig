#!/usr/bin/tclsh

# assuming the monitor configuration is in the parent directory
set current_dir [file normalize [file join [file dirname [info script]] ..]]

cd $current_dir

set curr_dir_pos [lsearch $auto_path $current_dir]
if {$curr_dir_pos < 0} {
    set auto_path [concat $current_dir $auto_path]
} elseif {$current_dir_pos > 0} {
    set auto_path [concat $current_dir [lreplace $auto_path $current_dir_pos $current_dir_pos]]
}

package require fileutil
package require syslog
package require unix_sockets
package require tdbc
package require tdbc::postgres
package require ngis::servicedb
package require ngis::conf
package require json

set next_entity 0
set json_txt ""

proc socket_readable {con} {
    global json_txt
    if {[chan eof $con]} {
        puts "eof detected"
        chan close $con
        #my stop_client
        return
    }

    set json_line [chan gets $con]
    puts $json_line
    append json_txt $json_line

    if {[catch { set msg_d [::json::json2dict $json_txt] }]} {
        return
    }

    puts "msg_d: $msg_d"
    set server_msg "got [dict get $msg_d code] ([dict get $msg_d message])"
    #syslog -perror -ident snig -facility user info 
    incr ::next_service
}

if {$argc == 0} {
    puts "no arguments..."
} else {
    set services_l [fileutil::cat [lindex $argv 0]]
    puts "checking [llength $services_l] services"
}

#set sql "select entity,count(ul.gid) cnt from testsuite.uris_long ul group by entity order by cnt asc"
#set resultset [::ngis::service exec_sql_query $sql]

set con [unix_sockets::connect $::ngis::unix_socket_name]
chan event $con readable [namespace code [list socket_readable $con]]
#puts "found [$resultset rowcount] rows"
set services_checked 0
chan puts $con "FORMAT JSON"
chan flush $con
vwait ::next_service
foreach service $services_l {

    puts "checking $service"

    chan puts $con "CHECK $service"
    chan flush $con

    vwait ::next_service

    if {[incr services_checked] > 10} { break }
    after 1000
}
