# --snig

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
        }

        public method prepare_page {language argsqs} {
            ### if we are here then the URL argument
            # 'service' was defined. We don't check it out

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

        public method print_content {language args} {
            set template_o [::rivetweb::RWTemplate::template $::rivetweb::template_key]
            set ns [$template_o formatters_ns]
            puts [${ns}::service_table $service_d]
        }
    }
}
