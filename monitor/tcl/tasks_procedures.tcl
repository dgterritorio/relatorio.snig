# -- tasks_procedures.tcl
#
# procedures to be executed by worker threads
#


package require http 2
package require uri
package require tls

http::register https 443 [list ::tls::socket -tls1 true]

set curr_dir [file join [file dirname [info script]] ".."]
set curr_dir [file normalize $curr_dir]

set dot [lsearch $auto_path $curr_dir]
if {$dot < 0} {
    set auto_path [concat $curr_dir $auto_path]
} elseif {$dot > 0} {
    set auto_path [concat $curr_dir [lreplace $auto_path $dot $dot]]
}

package require ngis::conf
package require ngis::msglogger
package require ngis::task
package require ngis::job
package require ngis::procedures
package require ngis::taskmessages

# we assume task_d is a well formed dictionary of data describing the task    
# as be created by calling ::ngis::tasks::mktask

namespace eval ::ngis::procedures {
    variable task_results_l ""

    proc fake_long_execution {job_thread_id thread_master_o duration {callback ""}} {
        ::ngis::logger emit "entering long wait.... ([::thread::id])"
        after [expr $duration*1000]
        ::ngis::logger emit "....wait terminated ([::thread::id])"

        thread::send -async $job_thread_id [list $thread_master_o move_to_idle [::thread::id]]
        if {$callback != ""} { thread::send -async $job_thread_id [list $callback $thread_master_o [::thread::id]] }
    }


    proc mockup_processing {task_d job_thread_id} {

        dict with task_d {
            ::ngis::logger emit "mockup processing of task $task for job [dict get $job jobname]"
            after 5000
            set status [::ngis::tasks::make_ok_result]
        }
        thread::send -async $job_thread_id [list [::ngis::tasks job_name $task_d] task_completed $task_d]

    }

    proc do_task {task_vector job_d} {
        set url [dict get $job_d uri]
        dict with task_vector {
            ::ngis::logger emit "running procedure '$procedure' (function '$function') for url '$url'"
            set status [::ngis::procedures::${procedure} $task_vector $job_d]
            ::ngis::logger emit "status returned '$status'"
        }
        #if {[string is true $::ngis::debugging]} {
        #    after $::ngis::debug_task_delay
        #} else {
        #    after $::ngis::task_delay
        #}
        #thread::send -async $job_thread_id [list [::ngis::tasks job_name $task_d] task_completed [thread::id] $task_d]

        return $status
    }

    ### 

    proc tasks_processing {job_tasks_l job_d} {
        variable task_results_l
        set task_d_l [lassign $job_tasks_l task_vector]

        lappend task_results_l [do_task $task_vector $job_d]

        if {([llength $task_d_l] == 0) || $::stop_signal_received} {
            ::ngis::service::update_task_results $task_results_l $job_d
            ::thread::send -async $job_thread_id [list $job_name tasks_have_completed [thread::id]]
        } else {
            after 100 [list [namespace current]::tasks_processing $task_d_l $job_d]
        }
    }

}

package provide ngis::tasks_procedures 2.0
