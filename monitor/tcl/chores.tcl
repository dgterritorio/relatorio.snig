# -- chores.tcl
#
#

package require ngis::conf
namespace eval ::ngis::chores {
    variable registered_chores ""

    proc exec_chores {master_thread} {
        variable registered_chores
        ::ngis::logger emit "exec [llength $registered_chores] registered chores"
        foreach c $registered_chores { $c exec }

        after [expr 1000 * $::ngis::chores_wait_time] [list [namespace current]::exec_chores $master_thread]
    }

    proc destroy_chores {} {
        variable registered_chores

        foreach c $registered_chores { $c destroy }
    }

    proc load_chores {master_thread} {
        variable registered_chores

        foreach cf [glob chores/*.tcl] {
            source $cf
            lappend registered_chores [::ngis::chores::tmp::mk_chore_obj]
        }
        namespace delete ::ngis::chores::tmp

        ::ngis::logger emit "chores loaded '$registered_chores'"
    }

}

package provide ngis::chores 1.0
