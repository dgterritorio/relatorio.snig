# -- job_controller.tcl
#
#

package require ngis::msglogger
package require ngis::job
package require ngis::threads
package require struct::queue

catch {::oo::class destroy ::ngis::JobController }

namespace eval ::ngis {

    ::oo::class create ::ngis::JobController

    ::oo::define ::ngis::JobController {
        variable sequence_list
        variable pending_sequences
        variable sequence_idx
        variable sequence_mark_idx
        variable thread_master
        variable round_robin_procedure
        variable task_results_chore
        variable task_results_queue
        variable load_balancer_chore
        variable jobs_quota
        variable shutdown_counter
        variable shutdown_signal

        constructor {max_workers_num} {
            set sequence_list           {}
            set sequence_idx            0
            set sequence_mark_idx       0
            set thread_master           [::ngis::ThreadMaster create ::ngis::thread_master $max_workers_num]
            set pending_sequences       {}
            set round_robin_procedure   ""
            set task_results_chore      ""
            set load_balancer_chore     ""
            set jobs_quota              $max_workers_num
            set task_results_queue      [::struct::queue ::ngis::task_results]
            set shutdown_signal         false
            set stop_operations         false
        }

        destructor {
            $thread_master destroy
        }

        method RescheduleRoundRobin {{multiple 1}} {
            if {$round_robin_procedure == ""} {
                ::ngis::logger debug "rescheduling job sequences round robin with delay multiplicator = $multiple"
                set round_robin_procedure \
                    [after [expr $multiple * $::ngis::rescheduling_delay] [list [self] sequence_roundrobin]]
            }
        }

        # -- LoadBalancerChore
        #
        # implements a flat policy of threads quota among sequences
        #

        method load_balancer_chore {} {
            set running_jobs [my running_jobs_tot]
            set max_threads_num $::ngis::max_workers_number

            set jobs_quota [expr 1 + int($max_threads_num/$running_jobs)]
        }

        method ScheduleLoadBalancer {} {
            if {$load_balancer_chore == ""} {
                set load_balancer_chore [after 2000 [list [self] load_balancer_chore]]
            }
        }

        method job_sequences {} {
            return [concat $sequence_list $pending_sequences]
        }

        method wait_for_operations_shutdown {} {
            if {([incr shutdown_counter -1] == 0) || ([llength $sequence_list] == 0)} {
                return
            }
            ::ngis::logger emit "\[$shutdown_counter\]: still [llength $sequence_list] sequences running"

            after 1000 [list [self] wait_for_operations_shutdown]
        }

        method server_shutdown {} {
            my stop_operations
            set shutdown_counter 11

            after 1000 [list [self] wait_for_operations_shutdown]
        }

        # stop_operations

        method stop_operations {} {
            foreach seq $sequence_list { $seq stop_sequence }
            # stopping the threads is actually not needed
            # as threads may be busy and we have just stopped
            # the jobs, as a matter of fact 
            #$thread_master stop_threads
        }

        method post_sequence {job_sequence} {
            ::ngis::logger emit "post sequence $job_sequence ([$job_sequence get_description])"
            lappend sequence_list $job_sequence
            my RescheduleRoundRobin

            if {[llength $sequence_list] > 1} {
                my ScheduleLoadBalancer
            }
        }

        method post_task_results {task_results} {
            #::ngis::logger emit "posting task result '$task_results'"

            $task_results_queue put $task_results
            if {([$task_results_queue size] >= $::ngis::task_results_queue_size) && \
                ($task_results_chore == "")} {
                after 100 [list $::ngis_server sync_results $task_results_queue]
            }

            my RescheduleRoundRobin
        }

        method post_task_results_cleanup {gid tasks_to_purge_l} {
            after 100 [$::ngis_server remove_results $gid $tasks_to_purge_l]
        }

        method move_thread_to_idle {thread_id} {
            $thread_master move_to_idle $thread_id
            my RescheduleRoundRobin
        }

        method sequence_terminates {seq} {
            ::ngis::logger emit "sequence $seq has completed"

            # check whether the sequence is already on the pending sequences list

            #::ngis::logger emit "searching $seq in >$pending_sequences< (pending seqs)"
            set idx [lsearch -exact $pending_sequences $seq]
            if {$idx >= 0} {
                set pending_sequences [lreplace $pending_sequences $idx $idx]
            } else {
                #::ngis::logger emit "searching $seq in >$sequence_list< (running seqs)"
                set idx [lsearch -exact $sequence_list $seq]
                if {$idx < 0} {
                    # it's should never get here
                    ::ngis::logger emit "server internal error [info object class]: invalid sequence"
                } else {
                    set sequence_list [lreplace $sequence_list $idx $idx]

                    # if the sequence just removed has an index < sequence_ids (the round_robin
                    # index) we must decrement it otherwise the round_robin would point to a position
                    # ahead

                    if {$idx < $sequence_idx} {
                        incr sequence_idx -1
                    }
                }
            }
            $seq destroy

            ::ngis::logger emit "[llength $sequence_list] sequences running, [llength $pending_sequences] pending"
            if {[llength $sequence_list] > 0} {
                foreach s $sequence_list {
                    ::ngis::logger emit "$s: '[$s get_description]' [$s running_jobs_count] jobs"
                }

                if {([llength $sequence_list] == 1) && ($load_balancer_chore != "")} {
                    after cancel $load_balancer_chore
                }
                my RescheduleRoundRobin
            } else {

                # any pending task result in the results buffer is stored in the database

                after 100 [list $::ngis_server sync_results $task_results_queue]

                if {$load_balancer_chore != ""} { after cancel $load_balancer_chore }

            }
        }

        method move_to_pending {seq} {
            ::ngis::logger emit "sequence $seq being moved to pending"
            set idx [lsearch -exact $sequence_list $seq]

            if {$idx < 0} {
                ::ngis::logger emit "error in [info object class]: invalid sequence"
            } else {
                set sequence_list [lreplace $sequence_list $idx $idx]
                if {$idx < $sequence_idx} {
                    incr sequence_idx -1
                }
                lappend pending_sequences $seq
            }
        }

        # -- running_jobs_tot
        #
        #

        method running_jobs_tot {} {
            set njobs 0
            foreach s [concat $sequence_list $pending_sequences] {
                set njobs [expr $njobs + [$s active_jobs_count]]
            }
            return $njobs
        }


        # -- sequence_roundrobin
        #
        # Round robin handling of job sequences. We execute one

        method sequence_roundrobin {} {
            set round_robin_procedure ""

            if {[string is true $shutdown_signal]} { return }

            if {[llength $pending_sequences] > 0} {

                # we copy 'pending_sequences' into the dumb variable
                # 'ps' because by calling 'sequence_terminates' we
                # modify the list

                set ps $pending_sequences
                foreach seq $ps {
                    if {[$seq active_jobs_count] == 0} {
                        my sequence_terminates $seq
                    } 
                }
            }

            if {[llength $sequence_list] == 0} { return }

            if {[$thread_master thread_is_available]} {

                # the sequence_idx (index) had been incremented
                # at the end of the previous run of sequence_roundrobin.
                # We reset it in case of overrun of the sequence_list

                if {$sequence_idx >= [llength $sequence_list]} {
                    set sequence_idx 0
                }

                # we must check whether a sequence is eligible to be scheduled
                set seq [lindex $sequence_list $sequence_idx]
                if {[$seq running_jobs_count] >= $jobs_quota} {

                    # we have found a sequence exceeding the 
                    # dyamic (though flat) job quota value.
                    # We resubmit the round-robin with a longer
                    # delay to determine a new sequence and
                    # allow for some job termination

                    incr sequence_idx
                    my RescheduleRoundRobin 2
                    return
                }

                set thread_id [$thread_master get_available_thread]
                if {[string is false [$seq post_job $thread_id]]} {

                    # let's return the thread to the idle thread pool
                    my move_thread_to_idle $thread_id

                    if {[$seq running_jobs_count] > 0} {
                        my move_to_pending $seq
                    } else {
                        my sequence_terminates $seq
                    }
                }

                # update the sequence_idx

                incr sequence_idx

                my RescheduleRoundRobin
            }
        }
        
		# -- status
		#
		# returns two forms of data:
        #    + argument jobs (default): returns the list of current 
        #               running sequences, the total number of jobs and
        #               the list of pending_sequences
        #    + argument thread_master: returns the status of the
        #               monitor thread master
		#
        method status {{argument "jobs"}} {
            if {$argument == "jobs"} {
                return [list $sequence_list [my running_jobs_tot] $pending_sequences]
            } elseif {$argument == "thread_master"} {
                return [$thread_master status]
            }
        }
    }
}

package provide ngis::jobcontroller 1.0
