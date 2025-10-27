# -- match_entity_hash
#
#

namespace eval ::ngis::entity_hash_map {
    variable hash_d         [dict create DGT 29 SRAAC 35 APA 54]
    variable hash_reverse_d [concat {*}[lmap {k v} $hash_d { list $v $k }]]
    variable entities_d     [dict create]

    proc hash_2_eid {hash} {
        variable hash_d

        if {[dict exists $hash_d $hash]} {
            return [dict get $hash_d $hash]
        }
        return ""
    }

    proc eid_2_hash {eid} {
        variable hash_reverse_d

        if {[dict exists $hash_reverse_d $eid]} {
            return [dict get $hash_reverse_d $eid]
        }
        return ""
    }

    proc init {dbhandle} {
        variable entities_d
        $dbhandle forall "select * from [::ngis::configuration::readconf entities_table]" e {
            set eid $e(eid)
            dict set entities_d $eid [array get e]
        }

    }

}

package provide ngis::entitymap 1.0
