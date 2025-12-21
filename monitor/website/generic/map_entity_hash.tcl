# -- match_entity_hash
#
#

package require md5
package require ngis::configuration

namespace eval ::ngis::entity_hash_map {
    # we do some caching here...
    variable hash_d         [dict create]
    variable hash_reverse_d [dict create]
    variable entities_d     [dict create]

    proc generate_hash {hash_len args} {
        set rf "/dev/urandom"
        set fp [open $rf r]
        chan configure $fp -eofchar "" -buffering none -translation binary -encoding binary
        set eb [read $fp 4096]
        close $fp
        binary scan $eb h* hexeb

        set    hashable_data    [join $args "-"]
        append hashable_data    $hexeb

        return [string range [::md5::md5 -hex -- $hashable_data] 0 $hash_len-1]
    }

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

    proc read_entity {dbhandle entity_key} {
        # search entity by

        if {[string is integer $entity_key]} {
            set eid $entity_key
        } elseif {[string is xdigit $entity_key]} {
            set eid [hash_2_eid $dbhandle $entity_key]
            if {$eid == ""} { return -code error -errorcode invalid_eid "Invalid entity eid or hash id" }
        } else {
            return -code error -errorcode invalid_eid "Invalid entity eid or hash key '$entity_key'"
        }
        ::ngis::configuration::readconf entities_table
        ::ngis::configuration::readconf entities_email

        if {[$dbhandle fetch $eid e1 -table $entities_table -keyfield {eid}] && \
            [$dbhandle fetch $eid e2 -table $entities_email -keyfield {eid}]} {
            array unset e2 gid
            return [dict merge [array get e1] [array get e2]]
        }

        return ""
    }

    proc update_entity {dbhandle entity_d} {
        array set entity_a [dict filter $entity_d key eid hash email manager]
        ::ngis::configuration::readconf entities_email
        return [$dbhandle update entity_a -table $entities_email -keyfield {eid}]
    }

    proc init {dbhandle} {
        variable entities_d
        $dbhandle forall "select * from [::ngis::configuration::readconf entities_email]" e {
        }
    }

}

package provide ngis::entitymap 1.0
