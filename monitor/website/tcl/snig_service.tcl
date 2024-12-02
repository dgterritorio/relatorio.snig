# snig_service --
#

package require ngis::page
package require ngis::servicedb
package require form
package require uri
package require ngis::dbresource
package require json

namespace eval ::rwpage {
    ::itcl::class SnigService {
        inherit SnigPage

        variable service_d

        constructor {key} {SnigPage::constructor $key} {
            set service_d [dict create]
        }

        public method js {} {
            set service_gid [$::rivetweb::current_page service_gid]
            ::rivet::parse js/start_tasks.js
            ::rivet::parse js/do_refresh.js
            puts {
$(document).ready(function () {
    $('#start_job').click(start_tasks);
    $('#refresh').click(do_refresh);
});
            }
        }

        public method prepare_page {language argsqs} {
            ### if we are here then the URL argument
            # 'service' was defined. We don't check it out

            set service_d [dict create]
            set service_id [dict get $argsqs service]
            set services_l [::ngis::service service_data $service_id]
            if {[llength $services_l] > 0} {

                # we expect to have only one service record
                # as the search key is the uris_long primary key

                set service_d [lindex $services_l 0]
                $this title $language [dict get $service_d description]
            } else {

            }
        }

        public method service_gid {} {
            if {[dict exists $service_d gid]} {
                return [dict get $service_d gid]
            }
        }

        public method print_content {language args} {
            set template_o [::rivetweb::RWTemplate::template $::rivetweb::template_key]
            set ns [$template_o formatters_ns]
            puts [${ns}::service_table $service_d]

            set start_checks  [::rivet::xml "Start Checks" [list button id "start_job"]]
            set refresh [::rivet::xml "Refresh" [list button id "refresh"]]
            set msgline [::rivet::xml "" [list span id "response"]]
            puts [::rivet::xml "$start_checks $refresh $msgline" [list div class bmessage]]
        }
    }
}
