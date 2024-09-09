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

set ::stop_signal false

proc stop_thread {} { set ::stop_signal true }

proc mockup_processing {job_o task} {
    set    task_name    [$task name]
    set    url          [$job_o url]
    ::ngis::logger emit "mockup processing of task $task_name for job $job_o"
    after 5000
    return [list $task_name ok "" "" $url]
}

proc job_completed {job_o} {
    thread::send -async $::job_controller_thread [list $::the_sequence job_completed [thread::id] [$job_o serialize]]
    $job_o destroy
}

proc do_single_task {job_o task_o} {
    if {($task_o == "DONE") || [string is true $::stop_signal]} {
        job_completed $job_o
        set ::stop_signal false
        return
    }

    set task_status [$task_o run $job_o]
    lassign $task_status task_name task_ret_status e einfo task_data
    ::ngis::logger emit "task $task_o returns $task_ret_status"

    if {$task_ret_status == "ok"} {
        # continue
    } elseif {$task_ret_status == "warning"} {
        ::ngis::logger emit "task for [$job_o jobname] returned '$task_data'"
    } else {
        job_completed $job_o
        return
    }

    set task_o [$task_o next]
    after 10 [list do_single_task $job_o $task_o]
}

proc exec_job {job_d the_sequence jc_thread} {
    set ::the_sequence          $the_sequence
    set ::job_controller_thread $jc_thread
    set ::stop_signal           false

    set job_o   [::ngis::Job create [dict get $job_d jobname] $job_d]
    set task_o  [$job_o seq_begin $::ngis::tasks::tasks]
    #set task   [$job_o seq_begin [list untested capabilities capabilities2]]

    after 10 [list do_single_task $job_o $task_o]
}

