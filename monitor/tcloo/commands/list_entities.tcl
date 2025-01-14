# list_entities.tcl --
#
#
#
#

package require ngis::servicedb

namespace eval ::ngis::client_server {

    ::oo::class create ListEntities {

        method exec {args} {
            set order "-nrecs"
            set pattern "%"
            if {[llength $args] > 0} {
                foreach a $args {
                    if {$a == "-alpha"} {
                        set order $a
                    } else {
                        set pattern $a
                    }
                }
            }
            return [list c108 [::ngis::service::list_entities $pattern $order]]
        }

    }

    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd ENTITIES cmd ENTITIES has_args maybe description "List Entities" help le.md]
        }
        proc mk_cmd_obj {} {
            return [::ngis::client_server::ListEntities create ::ngis::clicmd::ENTITIES]
        }
    }
}
