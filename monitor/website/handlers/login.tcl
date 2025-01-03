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

            set session_obj [::rwdatas::NGIS::get_session_obj]

            $session_obj activate
            set newsession [$session_obj is_new_session]

            if {$newsession} {
                if {$::ngis::debugging} {
                    #$session_obj store status logged    1
                    #$session_obj stash login  [dict create user "snig-dev"]
                    $session_obj store status logged    0
                } else {
                    $session_obj store status logged    0
                }
            }

            $::ngis::messagebox reset_message_queue

            if {![::rwdatas::NGIS::is_logged] && [::rivet::var_qs exists login]} {

                # this should simply send to the login form
                # a development installation automatically logs in
                # as administrative user

                if {$::ngis::debugging && ![::rivet::var_qs exists ignoredev]} {
                    $session_obj store status logged  1
                } else {
                    # there must be some user authentication here

                    set password [::rivet::var_qs get password nopwd]
                    set numrows  [::rwdatas::NGIS::check_password $password]
                    if {$numrows == 1} {
                        $session_obj store status logged  1
                    } else {
                        $session_obj store status logged  0
                    }
                }
                set key snig_homepage
                return -code break -errorcode rw_ok

            } elseif {[::rwdatas::NGIS::is_logged] && [::rivet::var_qs exists logout]} {

                $session_obj store status logged        0
                $session_obj clear login

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
                #$session_obj store status logged  1
                #return -code continue -errorcode rw_continue
            }

            return -code continue -errorcode rw_continue
        }

    }
}

package provide ngis::login 1.0
