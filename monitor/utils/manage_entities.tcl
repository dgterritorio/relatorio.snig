#!/usr/bin/tclsh
#
#

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
package require tdbc
package require tdbc::postgres
package require ngis::servicedb
package require ngis::conf

proc print_help_message {} {
    puts stderr "manage_entities.tcl ?--list? | ?--entity <entity name pattern>? | ?--eid eid1,eid2,eid3...,eidn? | ?-all?"
}

proc print_entities_table {} {
    
}

set regenerate_all  false
set eid_l           {}

if {$argc > 0} {
    set arguments $argv
    while {[llength $arguments]} {
        set arguments [lassign $arguments a]

        switch -nocase -- $a {
            --list {
                print_entities_table
                break
            }
            --entity {

            }
            --eid {
                set arguments [lassign $arguments eid_l]
                ::ngis::out "Regenerate hash for eid = $eid_l"
                regenerate_hash [split $eid_l ","]
                break
            }
            --all {
                set regenerate_all true
                ::ngis::out "Regenerating all hashes"
                break
            }
            default {
                print_help_message
            }
        }
    }
} else {
    return
}





