#!/usr/bin/tclsh8.6

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
package require ngis::tasks_procedures

package require ngis::hrformat

set arguments $argv
set gid ""
set eid ""
while {[llength $arguments]} {

    set arguments [lassign $arguments argname]
    switch $argname {
        -gid {
            set arguments [lassign $arguments gid]
        }
        -eid {
            set arguments [lassign $arguments eid]
        }
        default {
            puts "unknown argument: $argname"
        }
    }

}

::ngis::tasks build_tasks_database ./tasks

set ::ngis_server   [::ngis::Server create ::ngis_server]
set jcontroller     [::ngis_server create_job_controller 50]
set tm              ::ngis::thread_master

#set entity "Instituto Nacional de Estatística, I.P."
#puts "building the job sequence for $entity"

if {$gid != ""} {
    set service_l [list [::ngis::service::load_by_gid $gid]]
} elseif {$eid != ""} {
    set service_l [::ngis::service load_by_entity $eid]
}

if {[info exists service_l] && [llength $service_l] > 0} {
    set datasource   [::ngis::PlainJobList create ::jbsequenceds $service_l]
    set the_sequence [::ngis::JobSequence  create ::job_sequence $datasource ""]

    puts "created $datasource datasource for sequence $the_sequence"

    #$jcontroller post_sequence $the_sequence
}

#while {[$tm thread_is_available]} {
#    set thread_id [$tm get_available_thread]
#    puts "posting job to thread $thread_id"
#
#    $the_sequence post_job $thread_id
#}

#set hr_f [::ngis::HRFormat new]

::tclreadline::Loop
