#!/usr/bin/tclsh

set current_dir [concat [file normalize "."]]

set curr_dir_pos [lsearch $auto_path $current_dir]
if {$curr_dir_pos < 0} {
    set auto_path [concat $current_dir $auto_path]
} elseif {$current_dir_pos > 0} {
    set auto_path [concat $current_dir [lreplace $auto_path $current_dir_pos $current_dir_pos]]
}

package require ngis::server
package require ngis::task

set ::ngis_server [::ngis::Server create ::ngis_server]

# load the task database

::ngis::tasks build_tasks_database [list [file join $current_dir tasks]]

# create data root

if {[file exists [file join $::ngis::data_root tmp]] == 0} {
    file mkdir [file join $::ngis::data_root tmp]
}
if {[file exists [file join $::ngis::data_root data]] == 0} {
    file mkdir [file join $::ngis::data_root data]
}
$::ngis_server run $::ngis::max_workers_number
