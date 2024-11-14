# -- registered_tasks.tcl
#
#

package require ngis::task

catch { ::ngis::client_server::RegTasks destroy }

namespace eval ::ngis::client_server {

    ::oo::class create RegTasks {

        method identify {} {
            return [dict create cli_cmd REGTASK cmd REGTASKS has_args no description "List registered tasks" help lt.md]
        }

        method exec {args} {
            return [list c110 [::ngis::tasks list_registered_tasks]]
        }

    }

    namespace eval tmp {
        proc mk_cmd_obj {} {
            return [::ngis::client_server::RegTasks create ::ngis::clicmd::REGTASKS]
        }
    }

}
