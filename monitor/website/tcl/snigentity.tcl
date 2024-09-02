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
                dict set entity_recs $eid [dict create {*}[array get r]]
            }
        }

        public method print_content {language args} {
            


        }
    }

}

