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

        private variable entity_recs
        private variable entity_d
        private variable entity_o

        constructor {key} {SnigPage::constructor $key} {
            set entity_o [::ngis::Entity::mkobj]
        }

        destructor {
            $entity_o destroy
        }

        public method prepare_page {language argsqs} {
            set entity_recs [dict create]

            # if we're here there is an 'eid' url-encoded argument

            set eid [dict get $argsqs eid]
            set offset 0
            set limit  10
            if {[dict exists $argsqs offset]} {
                set offset [dict get $argsqs offset]
            }
            if {[dict exists $argsqs limit]} {
                set limit [dict get $argsqs limit]
            }

            ::ngis::conf readconf uris_table
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
            puts [::rivet::xml [${ns}::entity_service_recs $entity_recs] pre]
        }
    }

}
