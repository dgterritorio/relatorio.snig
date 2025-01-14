# -- snig_login.tcl
#
#
#

package require ngis::page
package require form
package require ngis::servicedb

namespace eval ::rwpage {

    ::itcl::class SnigLogin {
        inherit SnigPage

        constructor {key} {SnigPage::constructor $key} { }

        public method prepare_page {language argsqs} {

            $this title $language "Login"

        }
        public method print_content {language args} {
            ::rivet::parse [file join rvt loginform.rvt]
        }
    }

}

