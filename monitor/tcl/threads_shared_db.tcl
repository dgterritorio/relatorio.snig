# -- threads_shared_db.tcl
#
# if we want to venture into a shared memory model of thread status management
# procedures and shared state must have code common to threads
#

package require Thread
package require ngis::msglogger


namespace eval ::ngis::shared {
    if {![::tsv::exists snig timestamp]} {
        ::tsv::set snig timestamp [clock format [clock seconds]]
    }

    proc AddNewThread {tid} {
        ::tsv::lock snig {
            if {[::tsv::keylget snig threads_account $tid thread_d]} {
                ::ngis::logger emit "Thread $tid entry exists" error
            }
            ::tsv::keylset snig threads_account $tid [list nruns 0 last_run_start [clock seconds] last_run_end [clock seconds] status idle]
        }
    }

    proc RemoveThread {tid} {
        ::tsv::lock snig {
            ::tsv::keyldel snig threads_account $tid
        }
    }

    proc ReleaseAll {} {
        ::tsv::lock snig {
            foreach tid [::tsv::keylkeys snig threads_account] {
                ::thread::release $tid
            }
        }
    }


    proc PickThreadStatus {tid} {
        if {[::tsv::keylget snig threads_account $tid th_d]} {
            return $th_d
        }
        return [dict create]
    }

    proc StoreThreadStatus {tid th_d} {
        ::tsv::keylset snig threads_account $tid $th_d
    }

    proc BreakThreadAccDown {} {
        set running_threads_list {}
        set idle_threads_list {}

        ::tsv::lock snig {
            if {[::tsv::exists snig threads_account]} {
                foreach tid [::tsv::keylkeys snig threads_account] {
                    set thr_d [::tsv::keylget snig threads_account $tid]
                    set status_def [dict get $thr_d status]
                    lappend [dict get $thr_d status]_threads_list $tid
                }
            }
        }

        return [list $running_threads_list $idle_threads_list]
    }

    proc ChangeThreadStatus {tid new_status} {
        ::tsv::lock snig {
            set thread_status [::ngis::shared PickThreadStatus $tid]

            dict with thread_status {
                set status $new_status
                switch $new_status {
                    idle {
                        set last_run_end    [clock seconds]
                    }
                    running {
                        set last_run_start  [clock seconds]
                        incr nruns
                    }
                }
            }
            ::ngis::shared StoreThreadStatus $tid $thread_status
        }
    }

    namespace export *
    namespace ensemble create
}
package provide ngis::shared 1.0
