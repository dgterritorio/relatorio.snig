# task_results.tcl --
#
#

package require ngis::task
namespace eval ::ngis::client_server {

    ::oo::class create TaskResults {

        method exec {args} {

            # unlike QSERVICE command QTASK accepts only one argument
            # and it must be the gid of the associated service

            # set parsed_results [lassign [::ngis::utils::resource_check_parser $args "services"] res_status]

            # to avoid to call ::ngis::service service_data twice for any record for which a
            # description pattern is provided (as done within resource_check_parser) we assume
            # arguments are either integer or description strings

            set services_l {}
            foreach a $args {
                set s_l [::ngis::service service_data $a]
                if {[llength $s_l] > 0} {
                    lappend services_l {*}$s_l
                }
            }

            if {[llength $services_l] > 0} {
                return [list c118 $services_l [::ngis::tasks::list_registered_tasks]]
            } else {
                return [list c109 "No valid records found"]
            }

        }

    }

    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd TASKRES cmd QTASK has_args yes description "Display Task results" help tsk.md]
        }

        proc mk_cmd_obj {} {
            return [::ngis::client_server::TaskResults create ::ngis::clicmd::QTASK]
        }
    }
}
