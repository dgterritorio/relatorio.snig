package require ngis::page

namespace eval ::rwpage {

    ::itcl::class SnigUserList {
        inherit SnigPage

        private variable users_l

        constructor {key} {SnigPage::constructor $key} {
        }

        destructor {
        }

        public method prepare_page {language argsqs} {
            $this title $language "SNIG Monitor Users"
            $this headline $language "SNIG Monitor Users"
            set dbhandle [$this get_dbhandle]

            set sql "SELECT userid,login,ts from testsuite.snig_users"
            set users_l {}
            $dbhandle forall $sql u {
                lappend users_l [list $u(userid) $u(login) $u(ts) \
                                      [::rivet::xml "edit" [list a href [::rivetweb::composeUrl edituser $u(userid)]]] \
                                      [::rivet::xml "delete" [list a href [::rivetweb::composeUrl deleteuser $u(userid)]]] ]
            }

            $this close_dbhandle
        }

        public method print_content {language args} {
            set template_o  [::rivetweb::RWTemplate::template $::rivetweb::template_key]
            set ns [$template_o formatters_ns]
            puts [::rivet::xml "New User" [list div style "margin-bottom: 2em;"] [list a href [::rivetweb::composeUrl newuser 1]]]

            puts [::${ns}::mk_table {"Userid" "Login" "Created" "" ""} $users_l]
        }
    }

}
