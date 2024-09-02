# 

namespace eval ::ngis::tasks {

    proc make_ok_result {jobname {task_data ""}} {
        return [list $jobname ok "" "" $task_data [clock seconds]]
    }
    proc make_error_result {jobname {error_code ""} {error_info ""} {task_data ""}} {
        return [list $jobname error $error_code $error_info $task_data [clock seconds]]
    }
    proc make_warning_result {jobname {warning_code ""} {warning_info ""} {task_data ""}} {
        return [list $jobname warning $warning_code $warning_info $task_data [clock seconds]]
    }

}

package provide ngis::taskmessages 1.0
