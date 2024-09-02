#!/usr/bin/tclsh
#
#
#

set current_dir [concat [file normalize "."]]

if {[lindex $auto_path 0] != $current_dir} { set auto_path [list $current_dir {*}$auto_path] }

package require ngis::server

set ngis_server [::ngis::Server create ::ngis_server]

$ngis_server run $::ngis::max_workers_number
