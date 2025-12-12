# -- job.tcl
#
# class definining sets of tasks
#
#

package require TclOO
package require ngis::task
package require Thread

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
    variable tasks_l
    variable jobname
    variable job_status
    variable timestamp
    variable assigned_thread_id

    constructor {service_d_ {tsk_l ""}} {
        set sequence    ""
        if {$tsk_l == ""} { set tasks_l [::ngis::tasks get_registered_tasks] }
        set service_d   [dict filter $service_d_ key gid uuid entity description uri uri_original uri_type version jobname]
        if {![dict exists $service_d description]} { dict set service_d description "" }
        if {![dict exists $service_d version]} { dict set service_d version none }
        set jobname     [self]
        set job_status  created
        set timestamp   [clock seconds]
        set assigned_thread_id ""
    }

    destructor { }
 
    method status {} { return $job_status }
    method status_ts {} { return $timestamp }

    method set_sequence {its_sequence} { set sequence $its_sequence }
    method start_job {thread_id} {
        return [my schedule_job_tasks $thread_id]
    }

    method SetStatus {new_status} {
        set timestamp [clock seconds]
        set job_status $new_status
    }

    method stop_job {} {
        ::thread::send -async $assigned_thread_id { stop_thread }
        my SetStatus stop_signal_received
    }

    method job_tasks_have_completed {thread_id} {
        my SetStatus completed
        ::ngis::shared ChangeThreadStatus $thread_id idle
        if {$sequence != ""} { $sequence job_completed [self] }

        set assigned_thread_id ""
        return false
    }

    method schedule_job_tasks {thread_id} {

        set assigned_thread_id $thread_id
        set tasks_descr_l [::ngis::tasks list_tasks $tasks_l]

        ::thread::send -async $assigned_thread_id \
            [list ::ngis::procedures::start_tasks_processing $tasks_descr_l [[self] serialize]]
        my SetStatus running

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
