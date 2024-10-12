# -- 


package require http
package require uri
package require tls

http::register https 443 [list ::tls::socket -tls1 true]

lappend auto_path .

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
    thread::send -async $job_thread_id [list $job_o task_completed $task_d]

}

proc do_task {task_d job_thread_id} {
    variable wait_procedure

    set url [::ngis::tasks url $task_d]
    dict with task_d {
        ::ngis::logger emit "running procedure '$procedure' (function '$function') for url '$url'"
        if {[catch { set status [::ngis::procedures::${procedure} $task_d] } e einfo]} {
            set status [::ngis::tasks::make_error_result $e [dict get $einfo -errorcode] ""]
        }
    }

    set job_o [dict get $task_d job jobname]
    thread::send -async $job_thread_id [list [::ngis::tasks job_name $task_d] task_completed [thread::id] $task_d]
}

