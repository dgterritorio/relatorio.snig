# --
#
#

package require Thread
package require TclOO
package require tdbc::postgres
package require ngis::job
package require ngis::conf

catch { ::ngis::JobSequence destroy }

::oo::class create ::ngis::JobSequence {
    variable data_source
    variable description
    variable running_jobs
    variable current_job
    variable stop_signal
    variable completed_jobs

    constructor {ds {dscr ""}} {
        set data_source     $ds
        set description     $dscr
        set stop_signal     false
        set running_jobs    {}
        set current_job     ""
        set completed_jobs  0
    }

    destructor {
        $data_source destroy
    }

	method get_description {} { return $description }
    method active_jobs {} { return [my running_jobs_count] }
    method completed_jobs {} { return $completed_jobs }

    method job_scheduling_completed {job_o} {
        ::ngis::logger emit "$job_o scheduling has completed"
        #if {[info exists running_jobs($thread_id)]} { unset running_jobs($thread_id) }
    }

    method job_completed {job_o} {
        if {$job_o == $current_job} {
            set current_job ""
        } else {
            set j [lsearch $running_jobs $job_o]
            if {$j < 0} {
                ::ngis::logger emit "\[ERROR\] internal ::ngis::Job class error: $job_o not registered"
                return
            }
            set running_jobs [lreplace $running_jobs $j $j]
        }
        $job_o destroy
    }

    method running_jobs_count {} {
        set rj_number [llength $running_jobs]
        if {$current_job != ""} { incr rj_number }

        return $rj_number
    }

    method MarkForTermination {} {
        if {[my running_jobs_count] > 0} {
            ::the_job_controller move_to_pending [self]
        } else {
            ::the_job_controller sequence_terminates [self]
        }
    }

    method get_next_result {} { return [$data_source get_next] }

    method post_job {thread_id} {
        if {[string is true $stop_signal]} {
            ::ngis::logger emit "stop signal received: terminating [my running_jobs_count] running jobs"
            MarkForTermination
            return false
        }
        
        if {($current_job == "") || [string is false [$current_job post_task $thread_id]]} {
            set new_job [my get_next_result]

            if {$new_job == ""} {

                ::ngis::logger emit "no more jobs to send, [my running_jobs_count] still running"
                my MarkForTermination
                return false

            } else {

                $new_job set_sequence [self]

                if {$current_job != ""} { lappend running_jobs $current_job }
                set current_job $new_job

                 # this is a new job, we assume we have at least
                 # one task to perform

                ::ngis::logger emit "posting $current_job ([$current_job get_property record_description]) for new task"
                $current_job post_task $thread_id

            }
        }

        return true
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
            set job_o [::ngis::Job create [self object]::job${gid} $res_d [::ngis::tasks get_registered_tasks]]
            $job_o initialize

            return $job_o
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
            set job_o [::ngis::Job create [self object]::job${gid} $service_d [::ngis::tasks get_registered_tasks]]
            $job_o initialize
            lappend service_l $job_o
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

::oo::class create ::ngis::SingleTaskJob {
    variable job_o

    constructor {service_d task_code} {
        dict with service_d {
            set job_o [::ngis::Job create [self object]::job${gid} $service_d $task_code]
            $job_o initialize
        }
    }

    destructor {
        $job_o destroy
    }

    method get_next {} {
        return ""
    }
}

package provide ngis::sequence 1.0
