# --snig

package require ngis::page
package require form
package require uri
package require ngis::dbresource
#package require Thread
package require json

namespace eval ::rwpage {
    ::itcl::class SnigService {
        inherit SnigPage

        variable service_d

        constructor {key} {SnigPage::constructor $key} { }

        public method prepare_page {language argsqs} {
            ### if we are here then the URL argument
            # 'service' was defined. We don't check it out

            set service_id [dict get $argsqs service]
            set services_l [::ngis::servicedb service_data $service_id]
            if {[llength $services_l] > 0} {

                # we expect to have only one service record
                # as the search key is the uris_long primary key

                set service_d [llength $services_l 0]
            } else {

            }

        }

        public method print_content {language args} {
            #set service_fields_l {gid uuid description uri uri_type version}
            #array set legend_a [list gid gid description Description uri URL uri_type Type version Version uuid uuid]
            #set service_table_l [lmap f $service_fields_l {
            #    set row "<tr><td>$legend_a($f)</td><td>[dict get $service $f]</td></tr>"
            #}]
            #set service_table_l [join $service_table_l "\n"]
            #puts "<table>$service_table_l</table>"
        }
    }
}
