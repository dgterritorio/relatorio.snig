# -- job_controller.tcl
#
#

package require ngis::msglogger
package require ngis::job
package require ngis::threads

catch {::oo::class destroy ::ngis::JobController }

namespace eval ::ngis {

    ::oo::class create ::ngis::JobController

    ::oo::define ::ngis::JobController {
        variable sequence_list
        variable pending_sequences
        variable sequence_idx
        variable thread_master
        variable round_robin_procedure
        variable jobs_quota
        variable shutdown_counter
        variable shutdown_signal

        constructor {max_workers_num} {
            set sequence_list           {}
            set sequence_idx            0
            set thread_master           [::ngis::ThreadMaster create ::ngis::thread_master $max_workers_num]
            set pending_sequences       {}
            set round_robin_procedure   ""
            set jobs_quota              $max_workers_num
            set shutdown_signal         false
            set stop_operations         false
        }

        destructor {
            $thread_master destroy
        }

        method LogMessage {aMsg {method emit}} {
            ::ngis::logger $method "\[JOB_CONTROLLER\] $aMsg"
        }

        method RescheduleRoundRobin {} {
            if {$round_robin_procedure == ""} {
                my LogMessage "rescheduling job sequences round robin" debug
                set round_robin_procedure [after $::ngis::rescheduling_delay [list [self] sequence_roundrobin]]
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


        method start_chores_thread {} {
            $thread_master start_timed_chores [self]
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
            ::ngis::logger emit "posting new sequence $job_sequence ([$job_sequence get_description])"
            lappend sequence_list $job_sequence
            my LogMessage "Sequence list length: [llength $sequence_list]" debug
            my LoadBalancer
            my RescheduleRoundRobin
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
            # active job sequences on 'sequence_list'

            if {[llength $sequence_list] == 0} {
                after 100 [list $::ngis_server sync_results]

                if {[llength $pending_sequences] == 0} {
                    $thread_master terminate_idle_threads
                }
                return 
            }

            # the sequence_idx (index) could have been incremented
            # at the end of the previous run of sequence_roundrobin.
            # We wrap it if the value has reached the sequence_list size.
            # It's correct to wrap the 'sequence_idx' value *before*
            # scheduling new jobs because new sequences could be
            # posted after sequence_roundrobin returns control to
            # the event loop

            if {$sequence_idx >= [llength $sequence_list]} {
                set sequence_idx 0
            }

            # if there are no threads available we can return and wait for
            # some worker thread be returned to idle threads queue

            if {[string is false [$thread_master thread_is_available]]} {
                my LogMessage "no threads available. Pausing the round-robin" debug
                return
            }

            # let's go ahead and process the sequence pointed by 'sequence_idx'

            my LogMessage "processing sequence with index $sequence_idx" debug
            set seq [lindex $sequence_list $sequence_idx]
            set batch 0

            my LogMessage \
                "attempting to launch $::ngis::batch_num_jobs jobs (threads available: [$thread_master thread_is_available])" debug

            set sequence_has_terminated false
            while {[$thread_master thread_is_available] && ($batch < $::ngis::batch_num_jobs)} {

                # we must check whether a sequence is eligible to be scheduled

                if {[$seq running_jobs_count] >= max($::ngis::batch_num_jobs,int(0.9*$jobs_quota))} {

                    # This sequence is exceeding the dynamic (though flat)
                    # job quota value. We break out of the while loop

                    my LogMessage "$seq reached job quota ([$seq running_jobs_count] / $jobs_quota)" debug
                    break

                } else {

                    set thread_id [$thread_master get_available_thread]
                    if {[string is false [$seq post_job $thread_id]]} {

                        # let's return the thread back to the idle threads pool
                        my move_thread_to_idle $thread_id

                        set sequence_list [lreplace $sequence_list $sequence_idx $sequence_idx]
                        set sequence_has_terminated true

                        my LogMessage "sequence_list after removal of index $sequence_idx" debug
                        my LogMessage "$sequence_list" debug

                        if {[$seq running_jobs_count] == 0} {

                            # we are done with this job sequence

                            my LogMessage "destroying seq $seq" debug
                            $seq destroy

                        } else {

                            # There are still job running within the 
                            # sequence therefore we move it into the
                            # pending sequences list.

                            lappend pending_sequences $seq
                            my LogMessage "$seq moved to pending list" debug

                        }

                        # sequence_list size has changed then we call the
                        # load balancer to determine the new thread quota

                        my LoadBalancer

                        break
                    } else {
                        incr batch
                    }
                }
            }
            my LogMessage "launched $batch jobs for seq $seq" debug

            # there's no point to reschedule the round robin if no threads are available

            if {[string is true [$thread_master thread_is_available]]} {
                my RescheduleRoundRobin
            } else {
                my LogMessage "thread pool exhausted" debug
            }

            # we don't need to increment sequence_idx if this run resulted
            # in the job sequence being removed from sequence_list

            if {[string is false $sequence_has_terminated]} { incr sequence_idx }
        }
        
        # -- status
        #
        # Returns two forms of data:
        #
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
