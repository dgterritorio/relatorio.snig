package require UrlHandler
package require ngis::roothandler

namespace eval ::rwdatas {

    ::itcl::class Tests {
        inherit NGIS

        public method init {args} {
            chain {*}$args
            $this key_class_map snig_entity_stats ::rwpage::EntityStats tcl/snig_entity_stats.tcl
        }

        public method willHandle {arglist keyvar} {
            upvar $keyvar key
 
            # debugging
            #source generic/map_entity_hash.tcl
            # debugging

            if {[dict exists $arglist stats]} {
                set key snig_entity_stats
                return -code break -errorcode rw_code
            }

            return -code continue -errorcode rw_continue
        }

        public method menu_list {page} { return "" }
    }
}
package provide ngis::testhandler 1.0
