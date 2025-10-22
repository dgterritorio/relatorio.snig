# ----
#
#
package require UrlHandler
package require ngis::roothandler

namespace eval ::rwdatas {

    ::itcl::class Login {
        inherit NGIS

        public method init {args} {
            chain {*}$args
            $this key_class_map snig_login   ::rwpage::SnigLogin      tcl/snig_login.tcl
        }

        public method willHandle {arglist keyvar} {
            upvar $keyvar key

            set session_obj     [::rwdatas::NGIS::get_session_obj]

            $session_obj activate
            set newsession      [$session_obj is_new_session]
            set development     [::ngis::configuration readconf development]

            if {$newsession} {
                $session_obj store status logged 0
            }

            if {![::rwdatas::NGIS::is_logged] && [::rivet::var_qs exists login]} {

                # this should simply send to the login form
                # a development installation automatically logs in
                # as administrative user

                # there must be some user authentication here

                set password [::rivet::var_post get password nopwd]
                set login    [::rivet::var_post get username dgt]
                set numrows  [::rwdatas::NGIS::check_password $login $password userid]

                if {$numrows == 1} {
                    $session_obj store status logged 1
                    $session_obj store status login  $login
                    $session_obj store status userid $userid
                } else {
                    $::ngis::messagebox post_message "Invalid user or password" error
                    $session_obj store status logged 0
                    set key snig_login
                    return -code break -errorcode rw_ok
                }
                set key snig_homepage
                return -code break -errorcode rw_ok

            } elseif {[::rwdatas::NGIS::is_logged] && [::rivet::var_qs exists logout]} {

                $session_obj store status logged 0
                $session_obj clear status login
                $session_obj clear status userid

                #::rivet::redirect [::rivetweb::composeUrl]
                set key snig_login
                return -code break -errorcode rw_ok

            }

            if {![::rwdatas::NGIS::is_logged]} {
                if {!$::rivetweb::is_homepage} {
                    $::ngis::messagebox post_message "Please login"
                }
                set key snig_login
                return -code break -errorcode rw_ok
            }

            return -code continue -errorcode rw_continue
        }

    }
}

package provide ngis::login 1.0
