# static_content.tcl --
#
# This handler works like a fence in front of XMLBase. If
# the session status is not logged in menthod next_handler
# returns ::RWDummy
#
#

package require ngis::roothandler

namespace eval ::rwdatas {
    ::itcl::class StaticContentFence {
        inherit NGIS

        public method next_handler {} {
            if {[::rwdatas::NGIS::is_logged]} {
                return [UrlHandler::next_handler]
            } else {
                return [lindex [UrlHandler::registered_handlers] end]
            }
        }

        public method menu_list {page} { return "" }
        public method willHandle {arglist keyvar} { return -code continue -errorcode rw_continue }
    }
}
package provide ngis::content_fence 1.0

