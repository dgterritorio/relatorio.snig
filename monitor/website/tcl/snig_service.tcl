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

        variable service

        constructor {key} {SnigPage::constructor $key} { }

        public method prepare_page {language argsqs} {
            ### if we are here then the URL argument
            # 'service' was defined. We don't check it out

            set service_id [dict get $argsqs service]
            set con [socket $::ngis::tcpaddr $::ngis::tcpport]

            chan puts  $con "FORMAT JSON"
            chan flush $con

            set answer ""
            while {[chan gets $con l] > 0} {
                append answer $l
            }

            set answer_d [::json::json2dict $answer]

            if {![dict exists $answer_d code] || \
                ([dict get $answer_d code] != "104")} {
                return -code error -errorcode wrong_peer_answer "Server return invalid answer: '$answer'"
            }

            chan puts  $con "QURL $service_id"
            chan flush $con
            set answer ""
            while {[chan gets $con l] > 0} {
                append answer $l
            }

            chan close $con
            set answer_d [::json::json2dict $answer]
            set services_l [dict get $answer_d "services"]

            # should be just one

            set service [lindex $services_l 0]
        }

        public method print_content {language args} {
            set service_fields_l {gid uuid description uri uri_type version}
            array set legend_a [list gid gid description Description uri URL uri_type Type version Version uuid uuid]
            

            set service_table_l [lmap f $service_fields_l {
                set row "<tr><td>$legend_a($f)</td><td>[dict get $service $f]</td></tr>"
                set row
            }]
            set service_table_l [join $service_table_l "\n"]
            puts "<table>$service_table_l</table>"
        }
    }
}
