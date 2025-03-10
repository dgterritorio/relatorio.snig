package require ngis::page

namespace eval ::rwpage {

    ::itcl::class SnigUser {
        inherit SnigPage

        private variable rvt_template

        constructor {key} {SnigPage::constructor $key} {
        }

        public method prepare_page {language argsqs} {
            $this title $language "Create New User"
            if {[dict exists $argsqs newuser]} { 
                set rvt_template newuser.rvt
            } elseif {[dict exists $argsqs createuser]} {
                set login       [string trim [::rivet::var_post get login]]
                set password    [string trim [::rivet::var_post get password]]
                set rvt_template ""
                if {[string length $login] < 5} {
                    $ngis::messagebox post_message "Empty or invalid login"
                    set rvt_template newuser.rvt
                }
                if {[regexp -nocase {^[a-z][a-z0-9_]{8,}} $password] == 0} {
                    $ngis::messagebox post_message "Invalid password"
                    set rvt_template newuser.rvt
                }
            }
        }

        public method print_content {language} {
            ::rivet::parse [file join rvt $rvt_template]
        }

    }


}




