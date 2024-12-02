# reports.tcl --
#
# web service to return formatted reports from the server
#
package require ngis::webservice
package require ngis::servicedb
package require yajltcl

namespace eval ::rwpage {
    ::itcl::class SnigReports {
        inherit SnigWebService

        private variable json_o
        private variable report_n
        private variable data
        private variable fmtns

        constructor {key} {SnigWebService::constructor $key} {
            set json_o [yajl create [namespace current]::json -beautify 1]
            set fmtns [[::rivetweb::RWTemplate::template $::rivetweb::template_key] formatters_ns]
        }

        public method webservice {language argsqs} {
            $json_o reset 
            # if we're here the 'report' argument is defined
            set report_n [dict get $argsqs report]
            switch $report_n {
                118 {
                    set data [lindex [::ngis::service service_data [dict get $argsqs gid]] 0]
                }
                default {
                    SnigWebService::webservice $language $argsqs
                }
            }
        }

        public method print_content {language args} {
            switch $report_n {
                118 {
                    $json_o map_open string code string "618"
                    $json_o string title string [dict get $data description]
                    $json_o string report string [${fmtns}::service_tasks $data]
                    $json_o map_close
                }
            }
            puts [$json_o get]
        }
    }
}
