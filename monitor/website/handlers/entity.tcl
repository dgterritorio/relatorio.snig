package require UrlHandler
package require ngis::roothandler

namespace eval ::rwdatas {

    ::itcl::class Entity {
        inherit NGIS

        public method init {args} {
            chain {*}$args
            $this key_class_map snig_entity_stats ::rwpage::EntityStats tcl/snig_entity_stats.tcl
            $this key_class_map snig_entity_view  ::rwpage::ViewEntity  tcl/view_entity.tcl
            
            ::ngis::entity_hash_map::init [NGIS::get_dbhandle]
        }

        public method willHandle {arglist keyvar} {
            upvar $keyvar key
 
            # debugging
            #source generic/map_entity_hash.tcl
            # debugging
            set arglist [::rivetweb::strip_sticky_args $arglist]
            if {([dict size $arglist] == 1) && [dict exists $arglist stats]} {
                set dbhandle [::rwdatas::NGIS::attempt_db_connect]
                set eid [::ngis::entity_hash_map::hash_2_eid $dbhandle [dict get $arglist stats]]
                if { $eid == "" } {
                    # invalid entity hash
                } else {
                    dict set ::rivetweb::argsqs statseid $eid
                    set key snig_entity_stats
                    return -code break -errorcode rw_code
                }
            } elseif {[::rwdatas::NGIS::is_logged]} {
                set dbhandle [::rwdatas::NGIS::attempt_db_connect]
                if {[dict exists $arglist statseid]} {
                    set key snig_entity_stats
                    return -code break -errorcode rw_code
                } elseif {[dict exists $arglist viewent]} {
                    set key snig_entity_view
                    return -code break -errorcode rw_code
                }
            }

            return -code continue -errorcode rw_continue
        }

        public method menu_list {page} { return "" }
    }

}
package provide ngis::entityhandler 1.1
