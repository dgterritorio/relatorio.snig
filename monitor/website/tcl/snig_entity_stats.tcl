package require ngis::page
package require json

namespace eval ::rwpage {
    ::itcl::class EntityStats {
        inherit SnigPage
        private variable report_n

        constructor {key} {SnigPage::constructor $key} {
        }

        public method print_content {language args} {
            puts [::rivet::xml [info object class $this] h2]
            puts "<br /><pre>"
            dict for {k v}  $args { append  "$k --> $v"}
            puts "</pre>"
        }
    }
}
