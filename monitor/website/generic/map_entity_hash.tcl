# -- match_entity_hash
#
#

namespace eval ::ngis::entity_hash_map {
    variable hash_d         [dict create DGT 29 SRAAC 35 APA 54]
    variable hash_reverse_d [concat {*}[lmap {k v} $hash_d { list $v $k }]]

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

}
