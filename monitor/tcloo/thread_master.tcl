# -- thread_master.tcl
#

package require TclOO
package require Thread
package require ngis::chores
package require ngis::msglogger
package require ngis::shared

catch {::ngis::ThreadMaster destroy }

::oo::class create ::ngis::ThreadMaster {
    variable max_threads_number
    variable chores_thread_id

    constructor {mtn} {
        set max_threads_number      $mtn
        array set running_threads   {}
        set chores_thread_id        ""
    }

    destructor {
        ::ngis::shared ReleaseAll
        ::thread::release $chores_thread_id
    }

    method splice {} { return [::ngis::shared BreakThreadAccDown] }

    method get_threads_acc {} { 
        
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

    method status {} {
        lassign [::ngis::shared BreakThreadAccDown] running_threads_list idle_threads_list
        return [list [llength $running_threads_list] [llength $idle_threads_list]]
    }

    method start_timed_chores {jc} {

        set chores_thread_id [thread::create {
            set snig_monitor_dir [file normalize [file dirname [info script]]]

            # this is important
            cd $snig_monitor_dir

            set snig_monitor_dir_pos [lsearch $auto_path $snig_monitor_dir]
            if {$snig_monitor_dir_pos < 0} {
                set auto_path [concat $snig_monitor_dir $auto_path]
            } elseif {$snig_monitor_dir_pos > 0} {
                set auto_path [concat $snig_monitor_dir \
                    [lreplace $auto_path $snig_monitor_dir_pos $snig_monitor_dir_pos]]
            }
            package require ngis::conf
            package require ngis::chores
            package require ngis::msglogger

            namespace eval ::ngis::chores {
                variable job_controller ""
                variable thread_master  ""
                variable main_thread    ""

                ::ngis::logger emit "starting chores thread [thread::id]"
                load_chores [::thread::id]

                after 10000 [list [namespace current]::exec_chores]

                ::thread::wait
                destroy_chores
                ::ngis::logger emit "chores thread terminating"
            }
        }]

        thread::preserve $chores_thread_id

        thread::send $chores_thread_id [list set ::ngis::chores::job_controller $jc]
        thread::send $chores_thread_id [list set ::ngis::chores::thread_master  [self]]
        thread::send $chores_thread_id [list set ::ngis::chores::main_thread    [::thread::id]]

    }

    method start_worker_thread {} {

        set thread_id [thread::create {
            set ::master_thread_id ""
            set auto_path [concat [file dirname [info script]] $::auto_path]
            #puts $::auto_path
            package require ngis::conf
            package require ngis::tasks_procedures
            package require ngis::msglogger
            package require ngis::shared

            ::thread::wait
            ::ngis::logger emit "thread [thread::id] terminating"
            ::ngis::shared RemoveThread [::thread::id]
        }]

        thread::preserve $thread_id

        ::thread::send $thread_id [list set ::master_thread_id [::thread::id]]

        ::ngis::shared AddNewThread $thread_id

        return $thread_id
    }

    method thread_is_available {} {
        lassign [::ngis::shared BreakThreadAccDown] running_threads_list idle_threads_list

        if {[llength $idle_threads_list] > 0} { return true }
        if {[llength $running_threads_list] < $max_threads_number} { return true }
        return false
    }

    method get_available_thread {} {
        lassign [::ngis::shared BreakThreadAccDown] running_threads_list idle_threads_list
        ::ngis::logger emit "[llength $running_threads_list] running, [llength $idle_threads_list] idle threads" debug
        if {[llength $idle_threads_list] == 0} {
    
            if {[llength $running_threads_list] < $max_threads_number} {
                set thread_id [my start_worker_thread]
                ::ngis::logger debug "---> '$thread_id' started ========"
            } else {
                ::ngis::logger emit \
                    "Internal server error: running threads number exceeds max_threads_number"
                return -code 1 -errorcode thread_not_available "Running threads number exceeds max_threads_number"
            }

        } else {
            set thread_id [lindex $idle_threads_list 0]
        }

        return $thread_id
    }

    method thread_terminates {thread_id} {
        ::ngis::shared RemoveThread $thread_id
    }

    method move_to_idle {thread_id} {
        ::ngis::shared ChangeThreadStatus $thread_id idle
    }

    method move_to_running {thread_id} {
        ::ngis::shared ChangeThreadStatus $thread_id running
    }

    method running_threads {} {
        lassign [::ngis::shared BreakThreadAccDown] running_threads_list idle_threads_list
        return $running_threads_list
    }

    method idle_threads {} {
        lassign [::ngis::shared BreakThreadAccDown] running_threads_list idle_threads_list
        return $idle_threads_list
    }

    method broadcast {cmd} {
        foreach rt [my running_threads] { thread::send -async $rt $cmd }
    }

    method stop_threads {} {
        set threads_list [my running_threads]
        foreach running_thread $threads_list {
            thread::send -async $running_thread stop_thread
        }

        return [llength $threads_list]
    }

    method release_stale_threads {} {
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
                thread::release $thread_id
                #my thread_terminates $thread_id
            }
        }
    }

    method terminate_idle_threads {} {
        lassign [::ngis::shared BreakThreadAccDown] running_threads_list idle_threads_list 
        ::ngis::logger debug "[llength $idle_threads_list] threads on the idle list"
        foreach thread_id $idle_threads_list {
            thread::release $thread_id
        }
    }
}
package provide ngis::threads 2.0

