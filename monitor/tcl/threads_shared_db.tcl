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
            ::tsv::keylset snig threads_account $tid [list  nruns   0     \
                                                            last_run_start [clock seconds] \
                                                            last_run_end   [clock seconds] \
                                                            status  created \
                                                            gid     ""   \
                                                            task    none]
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
        set running_threads_list    {}
        set idle_threads_list       {}
        set created_threads_list    {}

        ::tsv::lock snig {
            if {[::tsv::exists snig threads_account]} {
                foreach tid [::tsv::keylkeys snig threads_account] {
                    set thr_d [::tsv::keylget snig threads_account $tid]
                    set status_def [dict get $thr_d status]
                    lappend [dict get $thr_d status]_threads_list $tid
                }
            }
        }

        return [list $running_threads_list $idle_threads_list $created_threads_list]
    }

    proc ChangeThreadStatus {tid new_status} {
        ::tsv::lock snig {
            set thread_status [::ngis::shared PickThreadStatus $tid]

            dict with thread_status {
                set status $new_status
                switch $new_status {
                    idle {
                        set last_run_end    [clock seconds]
                        set task            none
                        set gid             ""
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

    proc SetThreadTask {tid gid task} {
        ::tsv::lock snig {
            set thread_status [::ngis::shared PickThreadStatus $tid]
            dict set thread_status task $task
            dict set thread_status gid  $gid
            ::ngis::shared StoreThreadStatus $tid $thread_status
        }
    }

    proc release_stale_threads {} {
        set to_be_terminated {}
        
        ::tsv::lock snig {
            if {[::tsv::exists snig threads_account]} {
                foreach tid [::tsv::keylkeys snig threads_account] {
                    set thread_d [::tsv::keylget snig threads_account $tid]
                    dict with thread_d {
                        if {($status == "idle") && \
                            (($nruns > 10) || (([clock seconds]-$last_run_end) > 60))} {
                            lappend to_be_terminated $tid
                            set status exiting
                        }
                    }
                    ::tsv::keylset snig threads_account $tid $thread_d
                }
            }
            foreach thread_id $to_be_terminated {
                #thread::release $thread_id
                ::thread::send -async $thread_id { demand_thread_exit }
                #my thread_terminates $thread_id
            }
        }
    }

    proc get_threads_database {} { 
        
        ::tsv::lock snig {
            if {[::tsv::exists snig threads_account]} {
                set threads_acc_d [dict create]
                foreach tid [::tsv::keylkeys snig threads_account] {
                    dict set threads_acc_d $tid [::tsv::keylget snig threads_account $tid]
                }
            } else {
                set threads_acc_d [dict create]
            }
        }
        return $threads_acc_d

    }

    namespace export *
    namespace ensemble create
}
package provide ngis::shared 1.0
