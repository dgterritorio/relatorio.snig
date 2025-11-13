# -- job.tcl
#
# class definining sets of tasks
#
#

package require TclOO
package require ngis::task
package require Thread
package require struct::queue


oo::class create JobFactory {
    superclass oo::class
    method fromDict {d} {
        set o [my new]
        $o configure $d
        return $o
    }
}

::oo::class create ::ngis::Job



::oo::define ::ngis::Job {
    variable sequence
    variable service_d
    variable tasks_q
    variable tasks_l
    variable jobname
    variable job_status
    variable timestamp

    constructor {service_d_ tasks} {
        set sequence    ""
        set tasks_l     $tasks
        set tasks_q     [::struct::queue] 
        set service_d   [dict filter $service_d_ key gid uuid entity description uri uri_type version jobname]
        if {![dict exists $service_d description]} { dict set service_d description "" }
        if {[dict exists $service_d jobname] == 0} { set jobname [self] }
        set job_status  created
        set timestamp   [clock seconds]
    }

    destructor { }
 
    method task_queue {} { return $tasks_q }
    method status {} { return $job_status }
    method status_ts {} { return $timestamp }

    method set_sequence {its_sequence} { set sequence $its_sequence }

    method initialize {} {
        if {[$tasks_q size] > 0} { $tasks_q clear }
        $tasks_q put {*}[lmap t $tasks_l { ::ngis::tasks mktask $t [self] }]
    }

    method start_job {thread_id} {
        if {[$tasks_q size] > 0} { $tasks_q clear }

        $tasks_q put {*}[lmap t $tasks_l { ::ngis::tasks mktask $t [self] }]
        return [my post_task $thread_id]
    }

    method SetStatus {new_status} {
        set timestamp [clock seconds]
        set job_status $new_status
    }

    method stop_job {} {
        my SetStatus stop_signal_received
    }

    method notify_sequence {thread_id} {
        ::ngis::logger emit "Job [self] terminates"
        
        if {$sequence != ""} { $sequence job_completed [self] }
        # this call eventually reschedules the job sequence round robin
        [$::ngis_server get_job_controller] move_thread_to_idle $thread_id
    }

    method post_task {thread_id} {
        if {[string equal [my status] stop_signal_received] || [catch { set task_d [$tasks_q get] } e einfo]} {

            my SetStatus completed

            # the queue is empty, tasks are completed and
            # the job sequence the job belongs to is notified
            # that we are done with our tasks

            my notify_sequence $thread_id
            return false

        } else {

            set task_name [dict get $task_d task]
            my SetStatus $task_name

            ::ngis::logger emit "posting task '$task_name' for job [self]"

			# The last argument is the thread id of the caller (returned by ::thread::id)
			# as the worker thread needs to know the thread id of the sender in order
			# to send back the task results

            thread::send -async $thread_id [list do_task $task_d [thread::id]]
            return true

        }
    }

    method task_completed {thread_id task_d} {
        set task_result ""
        dict with task_d {
            ::ngis::logger emit "task '$task' for job '[self]' ends with status '$status' (tid: $thread_id)"

            set task_result $status
            lassign $task_result code

            if {$code == "not_applicable"} {
                ::ngis::logger emit "task not applicable. Results not posted"
            } else {
                $::ngis_server post_task_results $task_d

                # on an error code we interrupt the job

                if {$code == "error"} {
                    set tasks_results_to_remove [lrange $tasks_l [lsearch $tasks_l $task]+1 end]
                    if {[llength $tasks_results_to_remove] > 0} {
                        $::ngis_server post_task_results_cleanup [my gid] $tasks_results_to_remove
                    }
                    my notify_sequence $thread_id
                    return 
                }
            }

            # we don't need to change the job status here as we're not sending
            # deferred commands to the event loop before calling post_task (which
            # in turn determines the new status)

            my post_task $thread_id
        }
    }

    method serialize {} {
        return [my WholeObj]
    }

    method deserialize {d} {
        set service_d [dict filter $d key gid uuid entity description uri uri_type version]
        if {[dict exists $d jobname]} {
            set jobname [dict get $d jobname]
        } else {
            set jobname [self]
        }
        set tasks {}
        if {[dict exists $d tasks]} { set tasks [dict get $d tasks] }
    }

    method WholeObj {} {
        return [dict merge $service_d [dict create  tasks       $tasks_l \
                                                    jobname     $jobname \
                                                    job_status  $job_status \
                                                    timestamp   $timestamp]]
    }

    method get_property {jprops {output_form "-list"}} {
        set rv {}
        set obj_d [my WholeObj]

        if {$jprops == "all"} { return $obj_d }

        if {[llength $jprops] == 1} {
            if {[dict exists $obj_d $jprops]} {
                return [dict get $obj_d $jprops]
            } else {
                return ""
            }
        }

        if {$output_form == "-list"} {
            foreach jp $jprops {
                if {[dict exists $obj_d $jp]} {
                    lappend rv [dict get $obj_d $jp]
                }
            }
        } elseif {$output_form == "-dict"} {
            set rv [dict filter $obj_d key {*}$jprops]
        }
        return $rv
    }

    method set_property {args} {
        if {[llength $args]%2 != 0} { set args [lrange $args 0 end-1] }
        foreach {p v} $args {
            if {$p == "service_d"} {
                continue
            } elseif {$p == "url"} {
                dict set service_d uri $v
            } else {
                set $p $v
            }
        }
    }

    method set_jobname {n} { if {[string length $n] > 0} { set jobname $n } }

    method unknown {method_s args} {
        error "method '$method_s' not found"
    }

    method gid {} { return [my get_property gid] }
    method url {} { return [my get_property uri] }
    method type {} { return [my get_property type] }
    method version {} { return [my get_property version] }
    method uuid {} { return [my get_property uuid] }
    method jobname {} { return [my get_property jobname] }
}

package provide ngis::job 1.1
