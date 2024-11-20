# task_results.tcl --
#
#

namespace eval ::ngis::client_server {

    ::oo::class create TaskResults {
        method exec {args} {
            # unlike QSERVICE command QTASK accepts only one argument
            # and it must be the gid of the associated service
            set parsed_results [lassign [::ngis::utils::resource_check_parser $args "services"] res_status]
            if {$res_status == "OK"} {

                # after all for this command we are interested only in the gid value
                # returned by resource_check_parser and we don't event consider the
                # last 2 lists of parsed results

                lassign $parsed_results gids_l
                set services_l [::ngis::service service_data [lindex $gids_l 0]]

                # ::ngis::service::service_data returns a *list* of service records
                # even when this list is made of a single element. In this case
                # we expect to get just one service record

                return [list c118 $services_l]

            } else {

                # in case of error resource_check_parser may return a 109 error
                # It's stored in the 'code' variable

                lassign $parsed_results code a
                return [list c${code} $a]

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
