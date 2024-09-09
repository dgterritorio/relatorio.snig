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

            [$this get_dbhandle] forall "SELECT * from $uris_table where eid=$eid" r {
                dict set entity_recs $r(gid) [dict create {*}[array get r]]
            }
            set entity_o [::ngis::Entity::mkobj]
            set entity_d [$entity_o fetch [$this get_dbhandle] [list eid $eid]]
            if {[dict size $entity_d]} {
                $this title $language [dict get $entity_d description]
            }
            $entity_o destroy
        }

        public method print_content {language args} {
            set rows_l {}
            foreach gid [lsort -integer [dict keys $entity_recs]] {
                set entity [dict get $entity_recs $gid]

                dict with entity {

                    set uri_d [dict create {*}[uri::split $uri]]

                    set host ""
                    if {[dict exists $uri_d host]} {
                        set host [dict get $uri_d host]
                    }

                    lappend rows_l [::rivet::xml [join [list [::rivet::xml $gid td] \
                                                             [::rivet::xml $record_description td] \
                                                             [::rivet::xml $host td]] ""] tr]
                }

                puts [::rivet::xml [join $rows_l "\n"] [list table class table]]
            }
        }
    }

}
