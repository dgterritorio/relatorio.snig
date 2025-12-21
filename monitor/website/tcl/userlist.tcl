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
            $this title     $language "SNIG Monitor Users"
            $this headline  $language "SNIG Monitor Users"
            set dbhandle [$this get_dbhandle]

            set usertable [::ngis::configuration readconf users_table]
            set sql "SELECT userid,login,ts from $usertable"
            set users_l {}
            set session_obj      [::rwdatas::NGIS::get_session_obj]
            set current_login    [$session_obj fetch status login]
            set is_administrator [::rwdatas::NGIS::is_administrator $current_login]

            $dbhandle forall $sql u {
                set edituser_link   [::rivet::xml "edit" [list a href [::rivetweb::composeUrl edituser $u(userid)]]]
                set deleteuser_link [::rivet::xml "delete" [list a href [::rivetweb::composeUrl deleteuser $u(userid)]]]
                if {[regexp {(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.\d*} $u(ts) m v]} {
                    set u(ts) $v
                }

                if {$u(userid) == 1} { set deleteuser_link "---" }
                if {$is_administrator || ($u(login) == $current_login)} {
                    lappend users_l [list $u(userid) $u(login) $u(ts) $edituser_link $deleteuser_link]
                } else {
                    lappend users_l [list $u(userid) $u(login) $u(ts) "" ""]
                }
            }

            $this close_dbhandle
        }

        public method print_content {language args} {
            set template_o       [::rivetweb::RWTemplate::template $::rivetweb::template_key]
            set ns               [$template_o formatters_ns]
            set session_obj      [::rwdatas::NGIS::get_session_obj]
            set current_login    [$session_obj fetch status login]
            puts [::rivet::xml "New User"   \
                                [list div style "margin-bottom: 2em;"] [list a href [::rivetweb::composeUrl newuser 1]]]
            puts [::${ns}::mk_table {"Userid" "Login" "Created" "" ""} $users_l]
        }
    }

}
