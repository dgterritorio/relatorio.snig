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

        constructor {key} {SnigPage::constructor $key} {
        }

        public method prepare_page {language argsqs} {
            set entity_recs [dict create]

            # if we're here there is an 'eid' url-encoded argument

            set eid [dict get $argsqs eid]

            ::ngis::conf readconf uris_table
            set entity_recs {}

            set sql_base "SELECT * from $uris_table where eid=$eid order by description" 
            if {[dict exists $argsqs sort]} {
                switch [dict get $argsqs sort] {
                    gid {
                        set sql "SELECT * from $uris_table where eid=$eid order by gid"
                    }
                    description -
                    default {
                        set sql $sql_base
                    }
                }
            } else {
                set sql $sql_base
            }
            [$this get_dbhandle] forall $sql r {
                lappend entity_recs [array get r]
            }
            set entity_o [::ngis::Entity::mkobj]
            set entity_d [$entity_o fetch [$this get_dbhandle] [list eid $eid]]
            if {[dict size $entity_d]} {
                $this title $language [dict get $entity_d description]
            }
            $entity_o destroy
        }

        public method print_content {language args} {
            set template_o [::rivetweb::RWTemplate::template $::rivetweb::template_key]

            set rows_l {}
            set rows_l [lmap entity $entity_recs {

                list [dict get $entity gid] [dict get $entity description] \
                     [dict get $entity uri]

            }]

            set ns [$template_o formatters_ns]
            puts [${ns}::entities_table $rows_l]
        }
    }

}
