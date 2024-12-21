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
        variable thread_master
        variable round_robin_procedure
        variable task_results_chore
        variable task_results_queue
        variable jobs_quota
        variable shutdown_counter
        variable shutdown_signal

        constructor {max_workers_num} {
            set sequence_list           {}
            set sequence_idx            0
            set thread_master           [::ngis::ThreadMaster create ::ngis::thread_master $max_workers_num]
            set pending_sequences       {}
            set round_robin_procedure   ""
            set task_results_chore      ""
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
                ::ngis::logger debug "\[JOB_CONTROLLER\] rescheduling job sequences round robin with delay multiplicator = $multiple"
                set round_robin_procedure [after [expr $multiple * $::ngis::rescheduling_delay] [list [self] sequence_roundrobin]]
            }
        }

        # -- LoadBalancer
        #
        # implements a flat policy of threads quota among sequences
        #

        method LoadBalancer {} {
            set max_threads_num $::ngis::max_workers_number
            set num_sequences [llength $sequence_list]

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

            my RescheduleRoundRobin 1
        }

        method post_sequence {job_sequence} {
            ::ngis::logger emit "post sequence $job_sequence ([$job_sequence get_description])"
            lappend sequence_list $job_sequence
            syslog -ident snig -facility user info "\[JOB_CONTROLLER\] sequence_list after $job_sequence has been appended"
            syslog -ident snig -facility user info "\[JOB_CONTROLLER\] >$sequence_list<"
            my LoadBalancer
            my RescheduleRoundRobin 1
        }

        method post_task_results {task_results} {
            #::ngis::logger emit "posting task result '$task_results'"

            $task_results_queue put $task_results
            if {([$task_results_queue size] >= $::ngis::task_results_queue_size) && \
                ($task_results_chore == "")} {
                after 100 [list $::ngis_server sync_results $task_results_queue]
            }

            my RescheduleRoundRobin 1
        }

        method post_task_results_cleanup {gid tasks_to_purge_l} {
            after 100 [$::ngis_server remove_results $gid $tasks_to_purge_l]
        }

        method move_thread_to_idle {thread_id} {
            $thread_master move_to_idle $thread_id
            my RescheduleRoundRobin 1
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
                set pending_sequences [lmap seq $ps {
                    if {[$seq running_jobs_count] == 0} {
                        $seq destroy
                        continue
                    } else {
                        set seq
                    }
                }]
            }

            # we don't have anything to do here if there are no
            # active sequences on 'sequence_list'

            if {[llength $sequence_list] == 0} {
                after 100 [list $::ngis_server sync_results $task_results_queue]
                return 
            }

            # the sequence_idx (index) had been incremented
            # at the end of the previous run of sequence_roundrobin.
            # We reset it in case we overran the sequence_list size

            if {$sequence_idx >= [llength $sequence_list]} {
                set sequence_idx 0
            }

            if {[string is false [$thread_master thread_is_available]]} {
                syslog -ident snig -facility user info "\[JOB_CONTROLLER\] no threads available. Pausing the round-robin"
                return
            }

            syslog -ident snig -facility user info "\[JOB_CONTROLLER\] processing sequence with index $sequence_idx"
            set seq [lindex $sequence_list $sequence_idx]
            set batch 0

            while {[$thread_master thread_is_available] && ($batch < $::ngis::batch_num_jobs)} {

                # we must check whether a sequence is eligible to be scheduled

                if {[$seq running_jobs_count] >= int(0.9*$jobs_quota)} {

                    # This sequence is exceeding the dynamic (though flat)
                    # job quota value. We break out of the while loop

                    syslog -ident snig -facility user info "\[JOB_CONTROLLER\] $seq reached job quota ([$seq running_jobs_count] / $jobs_quota)"
                    break

                } else {

                    set thread_id [$thread_master get_available_thread]
                    if {[string is false [$seq post_job $thread_id]]} {

                        # let's return the thread back to the idle threads pool
                        my move_thread_to_idle $thread_id

                        set sequence_list [lreplace $sequence_list $sequence_idx $sequence_idx]

                        syslog -ident snig -facility user info "\[JOB_CONTROLLER\] sequence_list after removal of index $sequence_idx"
                        syslog -ident snig -facility user info "\[JOB_CONTROLLER\] >$sequence_list<"

                        if {[$seq running_jobs_count] == 0} {

                            # the sequence has terminated its jobs. We don't
                            # need to increment sequence_idx, since lreplace
                            # shifts sequences on the list to the right of
                            # the current index sequence

                            syslog -ident snig -facility user info "\[JOB_CONTROLLER\] destroying seq $seq"
                            $seq destroy

                        } else {

                            # the sequence turned down the just allocated thread
                            # and that means it has no more service records to be checked.
                            # We move the sequence into the pending sequences list.

                            lappend pending_sequences $seq
                            syslog -ident snig -facility user info "\[JOB_CONTROLLER\] $seq moved to pending list"

                        }
                        my LoadBalancer
                        break
                    } else {
                        incr batch
                    }
                }
            }

            # there's no point to reschedule the round robin if no threads are available

            if {[string is false [$thread_master thread_is_available]]} {
                syslog -ident snig -facility user info "\[JOB_CONTROLLER\] thread pool exhausted"
                return
            }

            syslog -ident snig -facility user info "\[JOB_CONTROLLER\] launched $batch jobs for seq $seq"
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
