# -- job.tcl
#
# class definining sets of tasks
#
#

package require TclOO
package require ngis::task
package require Thread

catch { ::oo::class destroy ::ngis::Job }

::oo::class create ::ngis::Job

::oo::define ::ngis::Job {
    variable service_d
    variable tasks
    variable jobname
    variable http_data

    constructor {service_d_} {
        set tasks       {}
        set service_d [dict filter $service_d_ key gid record_uuid record_entity record_description uri uri_type]
        set http_data   ""
        if {[dict exists $service_d_ jobname]} {
           set jobname [dict get $service_d_ jobname]
        } else {
           set jobname [self]
        }
    }

    method clear_tasks {} {
        foreach t $tasks { $t destroy }
        set tasks {}
    }

    destructor {
        my clear_tasks
    }
 
    method serialize {} {
        return [my WholeObj]
    }

    method deserialize {d} {
        set service_d [dict filter $d key gid record_uuid record_entity record_description uri uri_type]
        if {[dict exists $d jobname]} {
            set jobname [dict get $d jobname]
        } else {
            set jobname [self]
        }
        set http_data ""
        if {[dict exists $d http_data]} {
            set http_data [dict get $d http_data]
        }
        set tasks {}
        if {[dict exists $d tasks]} {
            foreach t [dict get $d tasks] {
                lappend tasks [::ngis::tasks::mktask [dict get $t task]] 
            }
            set prev ""
            foreach t $tasks {
                if {$prev == ""} {
                    set prev $t
                    continue
                } else {
                    $t set_previous $prev
                    $prev set_next $t
                    set prev $t
                }
            }
        }
    }

    method WholeObj {} {
        set task_l [lmap t $tasks { $t serialize }]

        return [dict merge $service_d [dict create  tasks     $task_l  \
                                                    http_data $http_data \
                                                    jobname   $jobname]]
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


    method set_jobname {n} { if {[string length $n] > 0} {set jobname $n} }

    method append_http_data {d} {
        append http_data $d
    }

    method get_http_data {} { return $http_data }

    method unknown {method_s args} {
        error "method '$method_s' not found"
    }

    method gid {} { return [my get_property gid] }
    method url {} { return [my get_property uri] }
    method jobname {} { return [my get_property jobname] }

    method seq_begin {seq_l} {
        my clear_tasks
        set sequence $seq_l

        set tasks [lmap t $seq_l { ::ngis::tasks::mktask $t }]
        set prev ""
        foreach t $tasks {
            if {$prev == ""} {
                set prev $t
                continue
            } else {
                $t set_previous $prev
                $prev set_next $t
                set prev $t
            }
        }
        return [lindex $tasks 0]
    }
}

package provide ngis::job 1.0
