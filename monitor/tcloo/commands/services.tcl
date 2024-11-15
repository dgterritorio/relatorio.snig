# services.tcl --
#
#

package require ngis::utils

namespace eval ::ngis::client_server {

    ::oo::class create Services {

        method exec {args} {

            # returns data regarding a series of service records (as specified by
            # mixed forms arguments in analogy with command CHECK, see 
            # resource_check_parser inutils/snigutils.tcl )

            set parsed_results [lassign [::ngis::utils::resource_check_parser $args "services"] res_status]
            if {$res_status == "OK"} {

                # the call to 'resource_check_parser' guarantees that
                # in case of success the 3 list gids_l eids_l services_l
                # are defined, at least as empty lists

                lassign $parsed_results gids_l eids_l services_l
                if {[llength $gids_l]} {
                    foreach gid $gids_l {

                        # ::ngis::service::service_data returns a *list* of service records
                        # even when this list is made of a single element

                        lappend services_l {*}[::ngis::service service_data $gid]
                    }
                }
                return [list c116 $services_l]
            } else {
                lassign $parsed_results code a
                return [list c${code} $a]
            }
        }
    }


    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd SERVICE cmd QSERVICE  has_args yes   description "Query Service Data" help url.md] \
        }
        proc mk_cmd_obj {} {
            return [::ngis::client_server::Services create ::ngis::clicmd::QSERVICE]
        }
    }

}
                
