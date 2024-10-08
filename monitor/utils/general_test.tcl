#!/usr/bin/tclsh

set dot [lsearch $auto_path "."]
if {$dot < 0} {
    set auto_path [concat "." $auto_path]
} elseif {$dot > 0} {
    set auto_path [concat "." [lreplace $auto_path $dot $dot]]
}
package require unix_sockets
package require tdbc
package require tdbc::postgres
package require ngis::servicedb
package require ngis::conf

set next_entity 0

proc socket_readable {con} {

    if {[chan eof $con]} {
        puts "eof detected"
        chan close $con
        my stop_client
        return
    }

    set server_msg [chan gets $con]
    puts $server_msg
    incr ::next_entity
}


set sql "select entity,count(ul.gid) cnt from testsuite.uris_long ul group by entity order by cnt asc"
set resultset [::ngis::service exec_sql_query $sql]

set con [unix_sockets::connect $::ngis::unix_socket_name]
chan event $con readable [namespace code [list socket_readable $con]]
#puts "found [$resultset rowcount] rows"

set entities [$resultset allrows -as dicts]
foreach ent $entities {

    puts "$ent"

    if {[dict exists $ent entity]} {
        set ent_name [dict get $ent entity]
        puts "sent request for $ent_name, waiting..."
        chan puts $con "CHECK \"$ent_name\""
        chan flush $con
    } else {
        continue
    }
    after 100

    vwait ::next_entity

}
