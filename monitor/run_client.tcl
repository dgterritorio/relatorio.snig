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
package require ngis::cli

namespace eval ::ngis::cli {
    variable cli [::ngis::CLI create ::cli $snig_monitor_dir]
}

set ::the_client [::ngis::Client new]
if {($argc > 0) && ([lindex $argv 0] == "--tcp")} {
    if {($argc == 2) && [regexp {(\d+\.\d+\.\d+\.\d+):(\d+)} [lindex $argv 1] m ipaddr port]} {
        $::the_client run $ipaddr $port
    } else {
        $::the_client run $::ngis::tcpaddr $::ngis::tcpport
    }
} else {
    # use unix domain socket
    $::the_client run
}

$::the_client destroy
