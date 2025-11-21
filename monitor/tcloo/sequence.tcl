# Sequence.tcl --
#
#

package require Thread
package require TclOO
package require tdbc::postgres
package require ngis::job
package require ngis::conf
package require ngis::common

catch { ::ngis::JobSequence destroy }

::oo::class create ::ngis::JobSequence {
    variable data_source
    variable description
    variable stop_signal
    variable num_of_completed_jobs
    variable running_jobs
    variable jobs_to_destroy

    constructor {ds {dscr ""}} {
        set data_source     $ds
        set description     $dscr
        set stop_signal     false
        set current_job     ""
        set num_of_completed_jobs  0
        set jobs_to_destroy {}
        set running_jobs    {}
    }

    destructor {
        $data_source destroy
        my delete_jobs
    }

	method get_description {} { return $description }
    method active_jobs_count {} { return [my running_jobs_count] }
    method active_jobs {} { return $running_jobs }
    method completed_jobs {} { return $num_of_completed_jobs }

    method delete_jobs {} {
        ::ngis::logger emit "[self] cleaning up finished jobs"
        foreach j $jobs_to_destroy { $j destroy }
    }

    # --job_completed
    #
    # callback from ::ngis::Job to signal that tasks are completed

    method job_completed {job_o} {
        incr num_of_completed_jobs
        lappend jobs_to_destroy $job_o

        set j [lsearch $running_jobs $job_o]
        if {$j < 0} {
            ::ngis::logger emit "\[ERROR\] internal ::ngis::Job class error: $job_o not registered"
            return
        }

        set running_jobs [lreplace $running_jobs $j $j]
    }

    method running_jobs_count {} {
        return [llength $running_jobs]
    }

    method njobs {} { return [$data_source njobs] }

    method get_next_result {} { return [$data_source get_next] }

    method post_job {thread_id} {
        if {[string is true $stop_signal]} {
            ::ngis::logger emit "stop signal received: terminating [my running_jobs_count] running jobs"
            return false
        }

        set new_job [my get_next_result]
        if {$new_job == ""} {

            return false

        } else {

            $new_job set_sequence [self]

            ::ngis::logger emit "starting $new_job ([$new_job get_property description])"
            lappend running_jobs $new_job

            $new_job start_job $thread_id
            return true

        }
    }

    method stop_sequence {} {
        set stop_signal true
        foreach j $running_jobs { $j stop_job }
    }
}

# Datasources --
#
# must implement two methods
#
#   + get_next: returns the next job in a sequence
#   + njobs: return the total number of jobs
#
# The JobSequence object is responsible to account
# for running and completed jobs

::oo::class create ::ngis::DataSource {

    variable jobs_created

    constructor {} {
        set jobs_created 0
    }

    method njobs {} { return 0 }
    method get_next {} { return "" }
    method jobs_created {} { return $jobs_created }
    method incr_jobs_created {} { incr jobs_created }

}


::oo::class create ::ngis::DBJobSequence {
    superclass ::ngis::DataSource

    variable result_set
    variable number_of_jobs

    destructor {
        $result_set close
    }

    constructor {tdbc_resultset} {
        set result_set $tdbc_resultset   
        set number_of_jobs [$tdbc_resultset rowcount]
    }

    method njobs {} { return $number_of_jobs }

    method get_next {} {
        if {[$result_set nextdict res_d]} {
            ::ngis::logger debug "returning data for service [dict get $res_d gid] ([dict get $res_d uri])"
            set gid [dict get $res_d gid]
            set job_o [::ngis::Job create [::ngis::JobNames new_cmd $gid] $res_d]
            return $job_o
        }
        return ""
    }

}

::oo::class create ::ngis::PlainJobList {
    superclass ::ngis::DataSource

    variable service_l
    variable service_l_length

    constructor {sl} {
        set service_l $sl
        set service_l_length [llength $service_l]
    }

    destructor {
        ::ngis::logger debug "[self] returned [my jobs_created] job objects out of $service_l_length initial service records"
    }

    method njobs {} { return $service_l_length }

    method get_next {} {
        set service_l [lassign $service_l service_rec_d]
        if { $service_rec_d == ""} { return "" }

        set gid [dict get $service_rec_d gid]
        set job_o [::ngis::Job create [::ngis::JobNames new_cmd $gid] $service_rec_d]]

        my incr_jobs_created
        return $job_o
    }

}

::oo::class create ::ngis::SingleTaskJob {
    superclass ::ngis::DataSource

    variable job_o

    constructor {service_d task_code} {
        dict with service_d {
            set job_o [::ngis::Job create [::ngis::JobNames new_cmd $gid] $service_d $task_code]
        }
    }

    destructor {
        #$job_o destroy
    }

    method njobs {} { return 1 }

    method get_next {} {
        return ""
    }
}

package provide ngis::sequence 1.0
