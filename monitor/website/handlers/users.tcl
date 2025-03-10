package require ngis::roothandler

namespace eval ::rwdatas {

    ::itcl::class Users {
        inherit NGIS

        public method init {args} {
            chain {*}$args
            $this key_class_map snig_userlist   ::rwpage::SnigUserList  tcl/userlist.tcl
            $this key_class_map snig_user       ::rwpage::SnigUser      tcl/snig_user.tcl
        }

        public method willHandle {arglist keyvar} { 
            upvar $keyvar key

            if {![::rwdatas::NGIS::is_logged]} { return -code continue -errorcode rw_continue }
            if {[dict exists $arglist userlist]} {
                set key snig_userlist
                return -code break -errorcode rw_ok
            } elseif {[dict exists $arglist newuser] || [dict exists $arglist createuser]} {
                set key snig_user
                return -code break -errorcode rw_ok
            }
            return -code continue -errorcode rw_continue
        }
        public method menu_list {page} { return "" }

    }
}

package provide ngis::users 1.0
