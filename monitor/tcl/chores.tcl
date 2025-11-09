# -- chores.tcl
#
#

package require ngis::servicedb

namespace eval ::ngis::chores {
    variable registered_chores [list notify_created_hash]

    proc exec_chores {master_thread tm_o} {
        variable registered_chores

        ::ngis::logger emit "executing chores"
        foreach chore $registered_chores {
            eval $chore
        }

        ::ngis::logger emit "chores executed"
        thread::send -async $master_thread [list $tm_o chores_completed]
    }

    proc notify_created_hash {} {



    }
}
