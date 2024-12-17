# 

namespace eval ::ngis::tasks {

    proc make_ok_result {{task_data ""}} {
        return [list ok "" "" $task_data [clock seconds]]
    }
    proc make_error_result {{error_code ""} {error_info ""} {task_data ""}} {
        return [list error $error_code $task_data $error_info [clock seconds]]
    }
    proc make_warning_result {{warning_code ""} {warning_info ""} {task_data ""}} {
        return [list warning $warning_code $warning_info $task_data [clock seconds]]
    }
    proc task_execution_error {error_code einfo_error task} { 
        return [list task_error $error_code $task $einfo_error [clock seconds]]
    }
}

package provide ngis::taskmessages 1.0
