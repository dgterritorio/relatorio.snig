# -- thread_master.tcl
#

package require TclOO
package require Thread
package require struct::queue

catch {::ngis::ThreadMaster destroy }

::oo::class create ::ngis::ThreadMaster {
    variable max_threads_number
    variable idle_thread_queue
    variable running_threads

    constructor {mtn} {
        set max_threads_number      $mtn
        set thread_pnt              0
        set thread_list             {}
        set idle_thread_queue       [::struct::queue]
        array set running_threads   {}
    }

    destructor {
        while {[$idle_thread_queue size] > 0} {
            thread::release [$idle_thread_queue get]
        }
        $idle_thread_queue destroy
    }

    method status {} {
        return [list [array size running_threads] [$idle_thread_queue size]]
    }

    method start_worker_thread {} {

        set thread_id [thread::create {
            source tcl/tasks_procedures.tcl

            ::ngis::logger emit "thread [thread::id] started"
            ::thread::wait
            ::ngis::logger emit "thread [thread::id] terminating"

        }]

        thread::preserve $thread_id
        return $thread_id

    }

    method thread_is_available {} {
        if {[$idle_thread_queue size] > 0} { return true }
        if {[array size running_threads] < $max_threads_number} { return true }
        return false
    }

    method get_available_thread {} {
        if {[$idle_thread_queue size] == 0} {
            if {[array size running_threads] < $max_threads_number} {
                set thread_id [my start_worker_thread]
                ::ngis::logger debug "'$thread_id' started ========"
            } else {
                ::ngis::logger emit \
                    "Internal server error: running threads number exceeds max_threads_number"
                return -code 1 -errorcode thread_not_available "Running threads number exceeds max_threads_number"
            }
        } else {
            set thread_id [$idle_thread_queue get]
        }

        my move_to_running $thread_id

        ::ngis::logger emit "[array size running_threads] running, [$idle_thread_queue size] idle threads"
        return $thread_id
    }

    method move_to_idle {thread_id} {
        if {[info exists running_threads($thread_id)]} {
            unset running_threads($thread_id)
        }
        $idle_thread_queue put $thread_id
        #puts "the idle queue has [$idle_thread_queue size] elements: [$idle_thread_queue peek [$idle_thread_queue size]]"
    }

    method move_to_running {thread_id} {
        set running_threads($thread_id) [clock seconds]
    }

    method running_threads {} { return [array names running_threads] }
    method idle_threads {{remove false}} {
        if {$remove} {
            set method get
        } else {
            set method peek
        }

        return [$idle_thread_queue $method [$idle_thread_queue size]]
    }

    method broadcast {cmd} {
        foreach rt [my running_threads] { thread::send -async $rt $cmd }
    }

    method stop_threads {} {
        set thread_list [array names running_threads]
        foreach running_thread $thread_list {
            thread::send -async $running_thread stop_thread
        }

        return [llength $thread_list]
    }

    method terminate_threads {} {
        while {[$idle_thread_queue size] > 0} {
            thread::release [$idle_thread_queue get]
        }
    }
}
package provide ngis::threads 1.0

