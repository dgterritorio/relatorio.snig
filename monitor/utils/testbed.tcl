#!/usr/bin/tclsh
# -- testbed.tcl
#
#

set dot [lsearch $auto_path "."]
if {$dot < 0} {
    set auto_path [concat "." $auto_path]
} elseif {$dot > 0} {
    set auto_path [concat "." [lreplace $auto_path $dot $dot]]
}

package require tclreadline

package require ngis::conf
package require ngis::server
package require ngis::servicedb
package require ngis::task
package require ngis::job
package require ngis::threads
package require ngis::sequence
package require ngis::jobcontroller
package require ngis::procedures

package require ngis::hrformat

set arguments $argv
set gid 212032
set eid ""
while {[llength $arguments]} {

    set arguments [lassign $arguments argname]
    switch $argname {
        gid {
            set arguments [lassign $arguments gid]
        }
        eid {
            set arguments [lassign $arguments eid]
        }
        default {
            puts "unknown argument: $argname"
        }
    }

}

::ngis::tasks build_tasks_database ./tasks

set ::ngis_server [::ngis::Server create ::ngis_server]

set jcontroller [::ngis_server create_job_controller 50]
set tm           ::ngis::thread_master
set gid_rec     [::ngis::service::load_by_gid $gid]

# faking a sequence
#::oo::define ::ngis::JobSequence {
#    method job_completed {job_o} {
#        puts "$job_o has completed"
#    }
#}

#set entity "Instituto Nacional de Estatística, I.P."
#puts "building the job sequence for $entity"

if {$eid != ""} {
    set service_l    [::ngis::service load_by_entity $eid]
    set datasource   [::ngis::PlainJobList create ::jbsequenceds $service_l]
    set the_sequence [::ngis::JobSequence create ::job_sequence $datasource ""]
}
set thread_id [$tm get_available_thread]
set job_o [::ngis::Job create ::job_object $gid_rec [::ngis::tasks get_registered_tasks]]

$job_o initialize
set q [$job_o task_queue]

set task_l [$q peek [$q size]]

foreach t $task_l {
    set task_a([dict get $t task]) $t
}

#source tcl/tasks_procedures.tcl
#$job_o post_task [thread::id]

#while {[$tm thread_is_available]} {
#    set thread_id [$tm get_available_thread]
#    puts "posting job to thread $thread_id"
#
#    $the_sequence post_job $thread_id
#}

#set hr_f [::ngis::HRFormat new]

::tclreadline::Loop
