# -- chores.tcl
#
#

namespace eval ::ngis::chores {
    variable registered_chores [list notify_hash_created terminate_idle_threads]

    proc exec_chores {master_thread tm_o} {
        ::ngis::logger emit "executing chores"
        after 1000
        ::ngis::logger emit "chores executed"
        thread::send -async $master_thread [list $tm_o chores_completed]
    }
}
