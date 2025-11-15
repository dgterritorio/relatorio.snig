# -- thread_master.tcl
#

package require TclOO
package require Thread
package require ngis::chores
package require ngis::msglogger

catch {::ngis::ThreadMaster destroy }

::oo::class create ::ngis::ThreadMaster {
    variable max_threads_number
    variable chores_thread_id

    variable threads_acc_d

    constructor {mtn} {
        set max_threads_number      $mtn
        array set running_threads   {}
        set chores_thread_id        ""
        set threads_acc_d           [dict create]
    }

    destructor {
        dict for {thr_id thr_d} $threads_acc_d {
            thread::release $thr_id
        }

        ::thread::release $chores_thread_id
    }

    method BreakThreadAccDown {} {
        set running_threads_list {}
        set idle_threads_list {}
        dict for {thr_id thr_d} $threads_acc_d {
            set status_def [dict get $thr_d status]
            lappend ${status_def}_threads_list $thr_id
        }
        return [list $running_threads_list $idle_threads_list]
    }

    method splice {} { return [my BreakThreadAccDown] }

    method get_threads_acc {} { return $threads_acc_d }

    method status {} {
        lassign [my BreakThreadAccDown] running_threads_list idle_threads_list
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

            ::thread::wait
            ::ngis::logger emit "thread [thread::id] terminating"

            ::thread::send $::master_thread_id [list ::ngis::thread_master thread_terminates [::thread::id]]
        }]

        thread::preserve $thread_id

        ::thread::send $thread_id [list set ::master_thread_id [::thread::id]]

        dict set threads_acc_d $thread_id \
            [dict create nruns 0 last_run_start [clock seconds] last_run_end [clock seconds] status idle]

        return $thread_id
    }

    method thread_is_available {} {
        lassign [my BreakThreadAccDown] running_threads_list idle_threads_list

        if {[llength $idle_threads_list] > 0} { return true }
        if {[llength $running_threads_list] < $max_threads_number} { return true }
        return false
    }

    method get_available_thread {} {
        lassign [my BreakThreadAccDown] running_threads_list idle_threads_list
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

        my move_to_running $thread_id

        return $thread_id
    }

    method thread_terminates {thread_id} {
        dict unset threads_acc_d $thread_id
    }

    method move_to_idle {thread_id} {
        dict set threads_acc_d $thread_id status idle
        dict set threads_acc_d $thread_id last_run_end [clock seconds]
    }

    method move_to_running {thread_id} {
        #set running_threads($thread_id) [clock seconds]
        dict with threads_acc_d $thread_id {
            set status running
            incr nruns
            set last_run_start [clock seconds]
        }
    }

    method running_threads {} {
        lassign [my BreakThreadAccDown] running_threads_list idle_threads_list
        return $running_threads_list
    }

    method idle_threads {} {
        lassign [my BreakThreadAccDown] running_threads_list idle_threads_list
        return $idle_threads_list
    }

    method run_chores {} {
        if {$chores_thread_id == ""} {
            set chores_thread_id [my get_available_thread]
            thread::send -async $chores_thread_id [list ::ngis::chores::exec_chores [::thread::id] [self]]
        }
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
        dict for {thread_id thread_d} $threads_acc_d {
            dict with thread_d {
                if {($status == "idle") && ($nruns > 10)} {
                    lappend to_be_terminated $thread_id
                }
            }
        }
        foreach thread_id $to_be_terminated {
            thread::release $thread_id
            my thread_terminates $thread_id
        }
    }

    method terminate_idle_threads {} {
        lassign [my BreakThreadAccDown] running_threads_list idle_threads_list 
        ::ngis::logger debug "[llength $idle_threads_list] threads on the idle list"
        foreach thread_id $idle_threads_list {
            thread::release $thread_id
        }
    }
}
package provide ngis::threads 2.0

