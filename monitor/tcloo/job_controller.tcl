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
        variable sequence_idx
        variable max_running_seqs
        variable thread_master
        variable pending_sequences
        variable round_robin_procedure
        variable task_results_chore
        variable task_results_queue
        variable shutdown_counter
        variable shutdown_signal

        constructor {max_workers_num} {
            set max_running_seqs        max_workers_num
            set sequence_list           {}
            set sequence_idx            0
            set thread_master           [::ngis::ThreadMaster create ::ngis::thread_master 10]
            set pending_sequences       {}
            set round_robin_procedure   ""
            set task_results_chore      ""
            set task_results_queue      [::struct::queue ::ngis::task_results]
            set shutdown_signal         false
        }

        destructor {
            $thread_master destroy
        }

        method RescheduleRoundRobin {} {
            if {$round_robin_procedure == ""} {
                set round_robin_procedure [after $::ngis::rescheduling_delay [list [self] sequence_roundrobin]]
            }
        }

        method wait_for_operations_shutdown {} {
            if {([incr shutdown_counter -1] == 0) || ([llength $sequence_list] == 0)} {
                return
            }
            ::ngis::logger emit "$shutdown_counter: still [llength $sequence_list] sequences running"

            after 1000 [list [self] wait_for_operations_shutdown]
        }

        method server_shutdown {} {
            my stop_operations
            set shutdown_counter 11

            after 1000 [list [self] wait_for_operations_shutdown]
        }


        method stop_operations {} {
            foreach seq $sequence_list { $seq stop_sequence }

            $thread_master stop_threads
        }

        method post_sequence {job_sequence} {
            lappend sequence_list $job_sequence
            my RescheduleRoundRobin
        }

        method post_task_results {task_results} {
            $task_results_queue put $task_results
            if {([$task_results_queue size] >= 10) && \
                ($task_results_chore == "")} {
                after 100 [list $::ngis_server sync_results $task_results_queue] 
            }

            my RescheduleRoundRobin
        }

        method move_thread_to_idle {thread_id} {
            $thread_master move_to_idle $thread_id
            my RescheduleRoundRobin
        }

        method sequence_terminates {seq} {
            ::ngis::logger emit "sequence $seq has completed"

            # check whether the sequence is already on the pending sequences list

            set idx [lsearch -exact $pending_sequences $seq]
            if {$idx >= 0} {
                set pending_sequences [lreplace $pending_sequences $idx $idx]
            } else {
                set idx [lsearch -exact $sequence_list $seq]
                if {$idx < 0} {
                    ::ngis::logger emit "error in [info object class]: invalid sequence"
                } else {
                    set sequence_list [lreplace $sequence_list $idx $idx]
                    if {$idx < $sequence_idx} {
                        incr sequence_idx -1
                    }
                }
            }
            $seq destroy

            ::ngis::logger emit "[llength $sequence_list] sequences pending"
            if {[llength $sequence_list] > 0} {
                my RescheduleRoundRobin
            } else {
                after 100 [list $::ngis_server sync_results $task_results_queue] 
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

        # -- sequence_roundrobin
        #
        # Round robin handling of job sequences. We execute one

        method sequence_roundrobin {} {
            set round_robin_procedure ""

            if {[string is true $shutdown_signal]} { return }

            if {[llength $pending_sequences] > 0} {
                set ps $pending_sequences
                foreach seq $ps {
                    if {[$seq active_jobs] == 0} {
                        my sequence_terminates $seq
                    } 
                }
            }

            if {[llength $sequence_list] == 0} { return }

            if {[$thread_master thread_is_available]} {
                if {$sequence_idx >= [llength $sequence_list]} {
                    set sequence_idx 0
                }

                set seq [lindex $sequence_list $sequence_idx]
                ::ngis::logger emit "processing sequence $seq"

                $seq post_job [$thread_master get_available_thread]
                incr sequence_idx

                my RescheduleRoundRobin
            }
        }
        
		# -- status
		#
		# returns the list of the current sequences and the number of
		# running sequences
		#
		method status {} {
            set njobs 0
            foreach s [concat $sequence_list $pending_sequences] {
                set njobs [expr $njobs + [$s active_jobs]]
            }
			return [list $sequence_list $njobs $pending_sequences]
		}

    }
}

package provide ngis::jobcontroller 1.0
