# -- threads.tcl --
#
# Returns information on the current working threads
#

namespace eval ::ngis::client_server {

    ::oo::class create ThreadsList {
        method exec {args} {
            set tm [[$::ngis_server get_job_controller] get_thread_master]
            return [list c124 [$tm get_threads_acc]]
        }
    }

    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd THREADS cmd THREADS has_args no description "List Active Worker Threads" help threads.md]
        }
        proc mk_cmd_obj {} {
            return [::ngis::client_server::ThreadsList create ::ngis::clicmd::THREADS]
        }
    }
}
