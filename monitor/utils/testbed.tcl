# -- testbed.tcl
#
#

set dot [lsearch $auto_path "."]
if {$dot < 0} {
    set auto_path [concat "." $auto_path]
} elseif {$dot > 0} {
    set auto_path [concat "." [lreplace $auto_path $dot $dot]]
}

package require ngis::conf
package require ngis::servicedb
package require ngis::task
package require ngis::job
package require ngis::threads
package require ngis::sequence
package require ngis::jobcontroller

set job_controller [::ngis::JobController create ::the_job_controller 100]
set tm ::ngis::thread_master
set gid_rec [::ngis::service::load_by_gid 3]

# faking a sequence
#::oo::define ::ngis::JobSequence {
#    method job_completed {job_o} {
#        puts "$job_o has completed"
#    }
#}

set resultset       [::ngis::service load_by_entity "Instituto Nacional de Estatística, I.P." -resultset]
set datasource      [::ngis::DBJobSequence create ::jbsequenceds $resultset]
set the_sequence    [::ngis::JobSequence new $datasource]

#set thread_id [$tm get_available_thread]
#set job_o [::ngis::Job create ::job_object $the_sequence $gid_rec [::ngis::tasks get_registered_tasks]]
#$job_o initialize 
#set q [$job_o task_queue]
#set task_d [$q get]
#source tcl/tasks_procedures.tcl
#$job_o post_task [thread::id]

while {[$tm thread_is_available]} {
    set thread_id [$tm get_available_thread]
    $the_sequence post_job $thread_id
}
