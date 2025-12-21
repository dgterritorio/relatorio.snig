package require json
package require yajltcl
package require fileutil
package require ngis::servicedb

namespace eval ::ngis::entity_data {
    variable entity_extended_dir "/var/tmp/snig.monitor"
    variable entity_extended     "entities.json"
    variable entities_d

    proc load_entity_table {} {
        variable entities_d
        set tdbc_results [::ngis::service::exec_sql_query "SELECT * from $::ngis::ENTITY_TABLE_NAME"]
        set entities_l [$tdbc_results allrows -as dicts]
        foreach e $entities_l {
            dict set entities_d [dict get $e eid] $e
        }
        
        $tdbc_results close
    }

    proc sync_data {} {
        variable entity_extended_dir
        variable entity_extended
        variable entities_d

        set json_o [yajl create [namespace current]::json -beautify 1]
        $json_o array_open
        foreach eid [lsort -integer [dict keys $entities_d]] {
            set e [dict get $entities_d $eid]
            set ordered_keys [lsort [dict keys $e]]
            $json_o map_open string eid integer $eid
            foreach k $ordered_keys {
                if {$k == "eid"} { continue }
                $json_o string $k string [dict get $e $k]
            }
            $json_o map_close
        }
        $json_o array_close
        fileutil::writeFile [file join $entity_extended_dir $entity_extended] [$json_o get]
        $json_o delete
    }

    proc fetch {eid} {
        variable entities_d

        if {[dict exists $entities_d $eid]} {
            return [dict get $entities_d $eid]
        }
        return ""
    }

    proc store {eid args} {
        variable entities_d

        dict for {k v} $args {
            dict set entities_d $eid $k $v
        }
        sync_data
    }

    proc init {} {
        variable entity_extended_dir
        variable entity_extended
        variable entities_d

        if {![file exists $entity_extended_dir]} {
            file mkdir $entity_extended_dir
            set entities_d [dict create]
        } else {
            set json_t      [::fileutil::cat [file join $entity_extended_dir $entity_extended]]
            set entities_l  [::json::json2dict $json_t]
            foreach e $entities_l {
                set eid [dict get $e eid]
                dict unset e eid
                dict set entities_d $eid $e
            }
        }
    }

}
