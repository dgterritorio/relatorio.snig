#!/usr/bin/tclsh
#
#
#
lappend auto_path .
package require ngis::client
package require ngis::conf

set client_o [::ngis::Client new]
if {($argc > 0) && ([lindex $argv 0] == "--tcp")} {
    if {($argc == 2) && [regexp {(\d+\.\d+\.\d+\.\d+):(\d+)} [lindex $argv 1] m ipaddr port]} {
        $client_o run $ipaddr $port
    } else {
        $client_o run $::ngis::tcpaddr $::ngis::tcpport
    }
} else {
    # use unix domain socket
    $client_o run
}

$client_o destroy
