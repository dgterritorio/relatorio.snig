set dot [lsearch $auto_path "."]
if {$dot < 0} {
    set auto_path [concat "." $auto_path]
} elseif {$dot > 0} {
    set auto_path [concat "." [lreplace $auto_path $dot $dot]]
}

package require ngis::threads

proc callback {tm thread_id} {
    puts "idle: [$tm idle_threads]"
    puts "running: [$tm running_threads]"

    if {[llength [$tm running_threads]] == 0} { incr ::wait_for_events }
}

set tm [::ngis::ThreadMaster create ::threadm 50]
set threads(1) [$tm start_worker_thread]
set threads(2) [$tm start_worker_thread]
set threads(3) [$tm start_worker_thread]
set threads(4) [$tm start_worker_thread]

foreach {n id} [array get threads] {
    ::thread::send -async $id [list fake_long_execution [::thread::id] $tm 15 ::callback]
    $tm move_to_running $id
    puts "idle: [$tm idle_threads]"
    puts "running: [$tm running_threads]"

    after 2000
}

vwait ::wait_for_events

dict for {id acc_d} [$tm get_threads_acc] {
    dict with acc_d {
        puts "$id: [clock format $last_run_start] > [clock format $last_run_end]"
    }
}
