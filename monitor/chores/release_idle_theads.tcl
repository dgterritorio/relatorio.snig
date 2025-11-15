package require Thread

namespace eval ::ngis::chores {
    ::oo::class create ReleaseStaleThreads {

        method identify {} {
            return [dict create class [namespace current]::ReleaseStaleThreads description "Send signal to release idle threads"]
        }

        method exec_chore {main_thread thread_master job_controller} {
            ::thread::send -async $main_thread [list $thread_master release_stale_threads]
        }
    }

    namespace eval tmp {
        proc mk_chore_obj {} {
            return [::ngis::chores::ReleaseStaleThreads create ::ngis::chores::release_stale]
        }
    }
}

