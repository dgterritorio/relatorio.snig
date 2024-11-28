# entity_services.tcl --
#
# class EntityServices returns a list of service records
# belonging to a specific entity

package require ngis::servicedb

namespace eval ::ngis::client_server {

    ::oo::class create EntityServices {

        method exec {args} {
            lassign $args eid offset limit

            if {$limit == ""} { set limit 100 }
            if {$offset == ""} { set offset 0 }

            set services_l [::ngis::service load_by_entity $eid -offset $offset -limit $limit]
            
            return [list c122 $services_l]
        }

    }

    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd LSSERV cmd LSSERV has_args yes \
                         description "List of service records for an Entity" help lsservices.md]
        }
        proc mk_cmd_obj {} {
            return [::ngis::client_server::EntityServices create ::ngis::clicmd::LSSERV]
        }
    }
}
