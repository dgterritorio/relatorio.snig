#
# -- snig.tcl
#
# Site home page

package require ngis::page
package require form
package require uri
package require ngis::dbresource

namespace eval ::rwpage {

    ::itcl::class SnigEntity {
        inherit SnigPage

        private variable eid
        private variable entity_recs
        private variable entity_d
        private variable entity_o

        private variable limit
        private variable offset
        private variable rowcount

        constructor {key} {SnigPage::constructor $key} {
            set entity_o [::ngis::Entity::mkobj]
        }

        destructor {
            $entity_o destroy
        }

        public method prepare_page {language argsqs} {
            set entity_recs [dict create]
            set srecs_limit [::ngis::conf::readconf service_recs_limit]

            # if we're here there is an 'eid' url-encoded argument

            set eid [dict get $argsqs eid]

            set offset 0
            set limit  ALL

            if {[dict exists $argsqs offset]} {
                set offset [dict get $argsqs offset]
            }
            if {[dict exists $argsqs limit]} {
                set limit [dict get $argsqs limit]
            } else {
                set limit $srecs_limit
            }

            if {[dict exists $argsqs rowcount]} {
                set rowcount [dict get $argsqs rowcount]
            } else {
                set rowcount [::ngis::service entity_service_recs_count $eid]
            }

            set entity_recs [::ngis::service load_by_entity $eid -limit $limit -offset $offset]
            set entity_recs [lmap er $entity_recs {
                dict with er {
                    set href [::rivetweb::composeUrl service $gid]
                    set description [::rivet::xml [dict get $er description] [list a href $href]]
                }
                set er
            }]
            set entity_d [$entity_o fetch [$this get_dbhandle] [list eid $eid]]
            if {[dict size $entity_d]} {
                $this title $language [dict get $entity_d description]
            } else {
                return -code error -errorcode entity_not_found "Error: entity '$eid' not found"
            }
        }

        public method print_content {language args} {
            set template_o [::rivetweb::RWTemplate::template $::rivetweb::template_key]
            set ns [$template_o formatters_ns]
            puts [${ns}::entity_service_recs $entity_recs [dict get $entity_d description]]

            set srecs_limit [::ngis::conf::readconf service_recs_limit]

            if {$rowcount > $srecs_limit} {
                set urls [lrepeat 4 {}] 
                if {$offset >= 2*$srecs_limit} {
                    lset urls 0 [::rivetweb::composeUrl eid $eid limit $srecs_limit offset [expr $offset - 2*$srecs_limit]]
                }
                if {$offset >= $srecs_limit} {
                    lset urls 1 [::rivetweb::composeUrl eid $eid limit $srecs_limit offset [expr $offset - $srecs_limit]]
                }
                if {$offset <= $rowcount - $srecs_limit} {
                    lset urls 2 [::rivetweb::composeUrl eid $eid limit $srecs_limit offset [expr $offset + $srecs_limit]]
                }
                if {$offset <= $rowcount - 2*$srecs_limit} {
                    lset urls 2 [::rivetweb::composeUrl eid $eid limit $srecs_limit offset [expr $offset + 2*$srecs_limit]]
                }
    
                puts [${ns}::navigation_bar $rowcount $offset $urls]
            }
        }
    }

}
