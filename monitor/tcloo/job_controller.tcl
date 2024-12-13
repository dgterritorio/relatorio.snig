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
            set load_balancer_chore ""
            set max_threads_num $::ngis::max_workers_number
            set num_sequences [my sequence_number_tot]

            if {$num_sequences <= 1} { 
                set jobs_quota $max_threads_num
            } else {
                set jobs_quota [expr 1 + int($max_threads_num/$num_sequences)]
                ::ngis::logger debug "LoadBalancer: computed jobs_quota = $jobs_quota ($max_threads_num/$num_sequences)"
            }
        }

        method job_sequences {} {
            return [concat $sequence_list $pending_sequences]
        }

        method sequence_number_tot {} {
            return [llength [my job_sequences]]
        }

        method wait_for_operations_shutdown {} {

            set jc_sequence_number [my sequence_number_tot]

            if {([incr shutdown_counter -1] == 0) || ($jc_sequence_number == 0)} {
                return
            }
            ::ngis::logger emit "\[$shutdown_counter\]: still $jc_sequence_number sequences running"

            after 1000 [list [self] wait_for_operations_shutdown]
        }

        method server_shutdown {} {
            my stop_operations
            set shutdown_counter 11

            after 1000 [list [self] wait_for_operations_shutdown]
        }

        # stop_operations

        method stop_operations {} {

            # signal sequences to stop jobs and
            # move them into the pending sequences list

            foreach seq $sequence_list { 
                $seq stop_sequence
                lappend pending_sequences $seq
            }
            set sequence_list [list]

            my RescheduleRoundRobin
        }

        method post_sequence {job_sequence} {
            ::ngis::logger emit "post sequence $job_sequence ([$job_sequence get_description])"
            lappend sequence_list $job_sequence
            my load_balancer_chore            
            my RescheduleRoundRobin
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

        # -- running_jobs_tot
        #
        #

        method running_jobs_tot {} {
            set njobs 0
            foreach s [concat $sequence_list $pending_sequences] {
                set njobs [expr $njobs + [$s running_jobs_count]]
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
                # 'ps' because by calling we modify this list

                set ps $pending_sequences
                set psidx 0
                foreach seq $ps {
                    if {[$seq running_jobs_count] == 0} {
                        set sequence_list [lreplace $sequence_list $psidx $psidx]
                    }
                }

            }

            # just in case there are pending sequences left
            # we reschedule the round robin in order to catch
            # up with their termination

            if {[llength $pending_sequences] > 0} {
                my RescheduleRoundRobin
            }

            # we don't have anything to do here if there are no
            # active sequences on 'sequence_list'

            if {[llength $sequence_list] == 0} { return }

            # the sequence_idx (index) had been incremented
            # at the end of the previous run of sequence_roundrobin.
            # We reset it in case we overran the sequence_list size

            if {$sequence_idx >= [llength $sequence_list]} {
                set sequence_idx 0
            }

            set seq [lindex $sequence_list $sequence_idx]
            set batch -1

            while {[$thread_master thread_is_available] && ([incr batch] < $::ngis::batch_num_jobs)} {

                # we must check whether a sequence is eligible to be scheduled

                if {[$seq running_jobs_count] >= $jobs_quota} {

                    # This sequence is exceeding the dynamic (though flat)
                    # job quota value. We break out of the while loop

                    break

                } else {

                    set thread_id [$thread_master get_available_thread]
                    if {[string is false [$seq post_job $thread_id]]} {

                        # let's return the thread to the idle thread pool
                        my move_thread_to_idle $thread_id

                        if {[$seq running_jobs_count] == 0} {

                            # the sequence has terminated its jobs. We don't
                            # need to increment sequence_idx, since lreplace
                            # lets shifts sequences on the list to the right of
                            # the current index sequence

                            set sequence_list [lreplace $sequence_list $sequence_idx $sequence_idx]

                        } else {

                            # the sequence turned down the just allocated thread
                            # and that means no more of its jobs need to be scheduled.
                            # We move the sequence into the pending sequences list

                            lappend pending_sequences $seq
                            set sequence_list [lreplace $sequence_list $sequence_idx $sequence_idx]

                        }
                        my RescheduleRoundRobin
                        my load_balancer_chore
                        return
                    }
                }
            }
            my RescheduleRoundRobin
            incr sequence_idx
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
