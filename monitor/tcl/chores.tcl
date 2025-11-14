# -- chores.tcl
#
#

package require ngis::conf
package require ngis::choreutils

namespace eval ::ngis::chores {
    variable registered_chores ""
    variable job_controller
    variable main_thread
    variable thread_master

    proc exec_chores {} {
        variable registered_chores
        variable main_thread
        variable thread_master
        variable job_controller

        ::ngis::logger emit "exec [llength $registered_chores] registered chores"
        foreach c $registered_chores { 
            $c exec_chore $chores_thread_id $main_thread $thread_master $job_controller
        }

        after [expr 1000 * $::ngis::chores_wait_time] [list [namespace current]::exec_chores]
    }

    proc destroy_chores {} {
        variable registered_chores

        foreach c $registered_chores { $c destroy }
    }

    proc load_chores {master_thread} {
        variable registered_chores

        foreach cf [glob [file join chores *.tcl]] {
            source $cf
            lappend registered_chores [::ngis::chores::tmp::mk_chore_obj]
        }
        namespace delete ::ngis::chores::tmp

        ::ngis::logger emit "chores loaded '$registered_chores'"
    }

}

package provide ngis::chores 1.0
