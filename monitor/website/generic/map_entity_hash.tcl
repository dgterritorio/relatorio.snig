# -- match_entity_hash
#
#

package require ngis::configuration

namespace eval ::ngis::entity_hash_map {
    # we do some caching here...
    variable hash_d         [dict create]
    variable hash_reverse_d [dict create]
    variable entities_d     [dict create]

    proc hash_2_eid {dbhandle hash} {
        variable hash_d
        variable hash_reverse_d

        if {[dict exists $hash_d $hash]} {
            return [dict get $hash_d $hash]
        } else {
            ::ngis::configuration::readconf entities_email
            if {[$dbhandle fetch $hash e -table $entities_email -keyfield {hash}]} {
                dict set hash_d $e(eid) $e(hash)
                dict set hash_reverse_d $e(hash) $e(eid)
                return $e(eid)
            }
        }
        return ""
    }

    proc eid_2_hash {dbhandle eid} {
        variable hash_d
        variable hash_reverse_d

        if {[dict exists $hash_reverse_d $eid]} {
            return [dict get $hash_reverse_d $eid]
        } else {
            ::ngis::configuration::readconf entities_email
            if {[$dbhandle fetch $eid e -table $entities_email -keyfield {eid}]} {
                dict set hash_d $e(eid) $e(hash)
                dict set hash_reverse_d $e(hash) $e(eid)
                return $e(hash)
            }
        }

        return ""
    }

    proc init {dbhandle} {
        variable entities_d
        $dbhandle forall "select * from [::ngis::configuration::readconf entities_email]" e {
        }
    }

}

package provide ngis::entitymap 1.0
