#!/usr/bin/tclsh8.6

# -- generate_entity_hashes
#
# Overall utility to generate missing hashes
#

set auto_path [concat [file join [file dirname [info script]] ".."] $auto_path]

package require ngis::conf
package require ngis::servicedb
package require syslog
package require md5

proc out {m} {
    syslog -pid -ident snig -facility syslog -perror info $m
}


set dbms [::ngis::service get_connector]

set tdbc_results [::ngis::service exec_sql_query "SELECT * from $::ngis::ENTITY_EMAIL"]
set entities_l [$tdbc_results allrows -as dicts]
$tdbc_results close

out "read [llength $entities_l] records"

foreach e $entities_l {
    set eid [dict get $e eid]
    out "examing entitity '$e'"
    if {![dict exists $e services_number] || ([dict get $e services_number] == 0)} { continue }
    if {(![dict exists $e hash] || ([string trim [dict get $e hash]] == "")) && [dict exists $e email]} {

            if {[string trim [dict get $e email]] == ""} {
                out "invalid or undefined email for entity [dict get $e entity]"
                continue
            }

            set rf "/dev/urandom"
            set fp [open $rf r]
            chan configure $fp -eofchar "" -buffering none -translation binary -encoding binary
            
            set eb [read $fp 4096]
            close $fp
            binary scan $eb h* hexeb
            set hash [string range [::md5::md5 -hex -- $hexeb] 0 15]
            set sql "UPDATE $::ngis::ENTITY_EMAIL SET hash='$hash' WHERE eid=$eid"

            set tdbc_res [::ngis::service exec_sql_query $sql]

    }
}

package provide ngis::genhashes
