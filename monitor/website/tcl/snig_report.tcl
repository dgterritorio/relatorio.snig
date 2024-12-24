
package require ngis::page
package require json

namespace eval ::rwpage {
    ::itcl::class DisplayReport {
        inherit SnigPage
        private variable report_n

        constructor {key} {SnigPage::constructor $key} {
        }

        public method js {} {
            ::rivet::parse js/loadreport.js
        }

        public method prepare_page {language argsqs} {
            set report_n [dict get $argsqs displayrep]
            switch $report_n {
                112 {
                    set title "Active Connections"
                }
                114 {
                    set title "Running Jobs"
                }
            }
            $this title $language $title
        }

        public method print_content {language args} {
            set template_o [::rivetweb::RWTemplate::template $::rivetweb::template_key]
            set ns [$template_o formatters_ns]
            puts [${ns}::report_page]
        }
    }

}
