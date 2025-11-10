package require fileutil
package require ngis::servicedb


namespace eval ::ngis::chores {
    ::oo::class create SendHashNotification {
        variable notified_hashes
        variable notified_hashes_fn

        constructor {} {
            set notified_hashes_fn [file join $::ngis::data_root notified_hashes.txt]
            if {[file exists $notified_hashes_fn]} {
                set notified_hashes [dict create {*}[::fileutil::cat $notified_hashes_fn]]
            } else {
                set notified_hashes [dict create]
            }
        }

        method identify {} {
            return [dict create class [namespace current]::SendHashNotification description "Sending hash based URLs"]
        }

        method exec {args} {
            ::ngis::logger debug "executing chore '[dict get [my identify] description]'"

            set     sql_l "SELECT ee.email,ee.manager,ee.hash,ee.eid FROM $::ngis::ENTITY_EMAIL AS ee JOIN"
            lappend sql_l "(SELECT ul.eid from $::ngis::TABLE_NAME AS ul group by ul.eid) AS eidl ON eidl.eid = ee.eid"

            set tdbc_res [::ngis::service exec_sql_query [join $sql_l " "]]
            set notify_services {}
            foreach r [$tdbc_res allrows -as dicts] {
                # an eid field must exists
                set eid [dict get $r eid]
                dict unset r eid
                if {[dict exists $r hash]} {
                    if {![dict exists $notified_hashes $eid] || \
                        ([dict get $notified_hashes $eid hash]  != [dict get $r hash]) || \
                        ([dict get $notified_hashes $eid email] != [dict get $r email])} {
                        lappend notify_services $eid
                        dict set notified_hashes $eid [dict filter $r key manager email hash]
                    }
                }
            }
            #::ngis::logger emit "notify services: $notify_services"
            if {[llength $notify_services] > 0} {
                foreach eid $notify_services {
                    dict with notified_hashes $eid {
                        ::ngis::logger emit "notify manager $manager at $email ($hash)"
                        
                    }
                }
                ::fileutil::writeFile $notified_hashes_fn $notified_hashes
            }
            unset notify_services
        }
    }

    namespace eval tmp {
        proc mk_chore_obj {} {
            return [::ngis::chores::SendHashNotification create ::ngis::chores::send_hash]
        }
    }
}
