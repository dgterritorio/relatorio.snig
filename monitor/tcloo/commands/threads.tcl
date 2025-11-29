# -- threads.tcl --
#
# Returns information on the current working threads
#

package require ngis::shared

namespace eval ::ngis::client_server {

    ::oo::class create ThreadsList {
        method exec {args} {
            return [list c124 [::ngis::shared::get_threads_database]]
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
