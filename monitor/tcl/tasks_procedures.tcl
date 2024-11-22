# -- 


package require http
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

set ::stop_signal false

proc stop_thread {} { set ::stop_signal true }

# we assume task_d is a well formed dictionary of data describing the task    
# as be created by calling ::ngis::tasks::mktask

proc mockup_processing {task_d job_thread_id} {

    dict with task_d {
        ::ngis::logger emit "mockup processing of task $task for job [dict get $job jobname]"
        after 5000
        set status [::ngis::tasks::make_ok_result]
    }
    thread::send -async $job_thread_id [list [::ngis::tasks job_name $task_d] task_completed $task_d]

}

proc do_task {task_d job_thread_id} {
    variable wait_procedure

    set url [::ngis::tasks url $task_d]
    dict with task_d {
        ::ngis::logger emit "running procedure '$procedure' (function '$function') for url '$url'"
        set status [::ngis::procedures::${procedure} $task_d]
    }

    if {[string is true $::ngis::debugging]} {
        ## debug
        after 5000 
        ## debug
    } else {
        after 1000
    }
    thread::send -async $job_thread_id [list [::ngis::tasks job_name $task_d] task_completed [thread::id] $task_d]
}
