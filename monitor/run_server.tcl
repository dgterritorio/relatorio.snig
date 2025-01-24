#!/usr/bin/tclsh8.6

package require syslog

set snig_monitor_dir [file normalize [file dirname [info script]]]

# this is important

cd $snig_monitor_dir

set snig_monitor_dir_pos [lsearch $auto_path $snig_monitor_dir]
if {$snig_monitor_dir_pos < 0} {
    set auto_path [concat $snig_monitor_dir $auto_path]
} elseif {$snig_monitor_dir_pos > 0} {
    set auto_path [concat $snig_monitor_dir [lreplace $auto_path $snig_monitor_dir_pos $snig_monitor_dir_pos]]
}

package require ngis::common
package require ngis::server
package require ngis::task
package require ngis::csprotomap

set ::ngis_server [::ngis::Server create ::ngis_server]

# load client server protocol 

# temporarily we place the cs protocol map in the global namespace

set ::ngis::ProtocolMap::cs_protocol [::ngis::ClientServerProtocolMap::build_proto_map $snig_monitor_dir -verbose true]

# load the task database

::ngis::tasks build_tasks_database [list [file join $snig_monitor_dir tasks]] -verbose

# create data root

if {[file exists [file join $::ngis::data_root tmp]] == 0} {
    file mkdir [file join $::ngis::data_root tmp]
}
if {[file exists [file join $::ngis::data_root data]] == 0} {
    file mkdir [file join $::ngis::data_root data]
}

syslog -ident snig -facility user info "SNIG Monitor Start"

$::ngis_server run $::ngis::max_workers_number
