# --
#
#

package require Thread
package require TclOO
package require tdbc::postgres
package require ngis::task
package require ngis::conf

catch { ::ngis::JobSequence destroy }

::oo::class create ::ngis::JobSequence {
    variable data_source
    variable description
    variable running_jobs
    variable stop_signal
    variable completed_jobs

    constructor {ds {dscr ""}} {
        set data_source     $ds
        set description     $dscr
        set stop_signal     false
        array set running_jobs {}
        set completed_jobs  0
    }

    destructor {
        $data_source destroy
    }

	method get_description {} { return $description }
    method active_jobs {} { return [array size running_jobs] }
    method completed_jobs {} { return $completed_jobs }

    method job_completed {thread_id tasks_results} {
        ::ngis::logger emit "$tasks_results has completed ([self object])"
        if {[info exists running_jobs($thread_id)]} { unset running_jobs($thread_id) }

        ::the_job_controller move_thread_to_idle $thread_id
        ::the_job_controller post_task_results $tasks_results
        incr completed_jobs
    }

    method get_next_result {} { return [$data_source get_next] }

    method get_job {{res_varname ""}} {
        set my_next_result [my get_next_result]
        if {$res_varname == ""} {
            return $my_next_result
        } else {
            upvar 1 $res_varname vn

            set vn $my_next_result
            return [expr [llength $my_next_result] > 0]
        }
    }

    method list_running_jobs {} {
        foreach {thread job_o} [array get running_jobs] {
            set job_d [$obj_o serialize]
            catch { dict unset job_d tasks }

            lappend active_job_list $job_d
        }
        return $active_job_list
    }

    method post_job {thread_id} {
        if {[my get_job job] && [string is false $stop_signal]} {
            thread::send -async $thread_id [list exec_job [$job serialize] [self] [thread::id]]
            set running_jobs($thread_id) $job
            return true
        } else {
            if {[string is true $stop_signal]} {
                ::ngis::logger emit "stop signal received: terminating [array size running_jobs] running jobs"
            } else {
                ::ngis::logger emit "no more jobs to send, [array size running_jobs] still running"
            }

            if {[array size running_jobs] > 0} {
                ::the_job_controller move_to_pending [self]
            } else {
                ::the_job_controller sequence_terminates [self]
            }
            return false
        }
    }

    method stop_sequence {} {
        set stop_signal true
    }
}

::oo::class create ::ngis::DBJobSequence {
    variable result_set
    variable last_job

    destructor {
        $result_set close
    }

    constructor {tdbc_resultset} {
        set result_set $tdbc_resultset   
        set last_job ""
        if {$last_job != ""} {
            $last_job destroy
        }
    }

    method get_next {} {
        if {[$result_set nextdict res_d]} {
            if {$last_job != ""} {
                $last_job destroy
            }

            set gid [dict get $res_d gid]

            return [::ngis::Job create [self object]::job${gid} $res_d]
        }
        return ""
    }

}

::oo::class create ::ngis::PlainJobList {

    variable service_l
    variable service_idx

    constructor {sl} {

        foreach service_d $sl {
            set gid [dict get $service_d gid]
            lappend service_l [::ngis::Job create [self object]::job${gid} $service_d]
        }

        set service_idx -1
    }

    destructor {
        foreach j $service_l { $j destroy }
    }

    method get_next {} {
        if {$service_idx < [llength $service_l]} {
            return [lindex $service_l [incr service_idx]]
        } else {
            return ""
        }
    }

}
package provide ngis::sequence 1.0
