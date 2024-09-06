#
# -- snig.tcl
#
# Site home page

package require ngis::page
package require form

namespace eval ::rwpage {

    ::itcl::class SnigEntity {
        inherit SnigPage

        private variable entity_recs

        constructor {key} {SnigPage::constructor $key} {
        }

        public method prepare_page {language argsqs} {
            set entity_recs [dict create]
            set eid [dict get $argsqs eid]

            ::ngis::conf readconf uris_table

            [$this get_dbhandle] forall "SELECT * from $uris_table where eid=$eid" r {
                dict set entity_recs $r(gid) [dict create {*}[array get r]]
            }
        }

        public method print_content {language args} {
            set rows_l {}
            foreach gid [lsort -integer [dict keys $entity_recs]] {
                set entity [dict get $entity_recs $gid]
                dict with entity {
                    lappend rows_l [::rivet::xml [join [list [::rivet::xml $gid td] \
                                                             [::rivet::xml $record_description td]] ""] tr]
                }

                puts [::rivet::xml [join $rows_l "\n"] [list table class table]]
            }
        }
    }

}
