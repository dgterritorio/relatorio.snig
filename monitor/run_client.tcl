#!/usr/bin/tclsh
#
#
#
set snig_monitor_dir [file dirname [info script]]

set snig_monitor_dir_idx [lsearch $auto_path $snig_monitor_dir]
if {$snig_monitor_dir_idx < 0} {
    set auto_path [concat $snig_monitor_dir $auto_path]
} elseif {$snig_monitor_dir_idx > 0} {
    set auto_path [concat $snig_monitor_dir [lreplace $auto_path $snig_monitor_dir_idx $snig_monitor_dir_idx]]
}

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
