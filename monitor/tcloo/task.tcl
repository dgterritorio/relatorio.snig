# -- task.tcl
#
#

package require TclOO
package require ngis::conf
package require ngis::msglogger
package require ngis::taskmessages

catch { ::ngis::Task destroy }

namespace eval ::ngis::tasks {

    variable tasks      [list untested congruence      connectivity capabilities capabilities2]
    variable procedures [list start    data_congruence http_status  get_url      run_bash]
    variable functions  [list ""       ""              ""           ""           readurl]
    variable taskn      -1

}


::oo::class create ::ngis::Task {
    variable next
    variable previous
    variable task
    variable procedure
    variable function
    variable data
    variable status

    constructor {t} {
        set tindex [lsearch $::ngis::tasks::tasks $t]
        if {$tindex < 0} { return -code 1 -errorcode task_not_found }

        set task        $t
        set procedure   [lindex $::ngis::tasks::procedures $tindex]
        set function    [lindex $::ngis::tasks::functions  $tindex]
        set next        DONE
        set prev        ""
        set status      ""
    }

    method serialize {} {
        return [list task $task procedure $procedure function $function status $status]
    }

    method deserialize {task_l} {
        foreach f [list task procedure function status] {

        }
    }

    method exit_status {} { return $status }

    method function {} { return $function }
    method name {} { return $task }
    method set_previous {p} { set previous $p }
    method set_next {n} { set next $n }

    method next {} { return $next }
    method previous {} { return $previous }
    method get_tasks {} { return $::ngis::tasks::tasks }

    method run {job_o} {
        ::ngis::logger emit "running procedure '$procedure' (function '$function') for job [$job_o jobname]"

        if {[catch {set status [::ngis::procedures::${procedure} $job_o $function]} e einfo]} {
            set status [::ngis::tasks make_error_result [$job_o jobname] error $e [dict get $einfo -errorcode] ""]
        }
        return $status
    }
}

namespace eval ::ngis::tasks {

    proc mktask {t} {
        variable tasks
        variable procedures
        variable functions

        set task_id [lsearch $::ngis::tasks::tasks $t]
        if {$task_id >= 0} {
            return [::ngis::Task create ::ngis::Task[incr ::ngis::tasks::taskn] [lindex $tasks $task_id]]
        }
        return -code 1 -errorcode invalid_task
    }
}

package provide ngis::task 0.1
