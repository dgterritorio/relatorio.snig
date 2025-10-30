#
# -- snig.tcl
#
# Site home page

package require ngis::page
package require form
package require ngis::servicedb

namespace eval ::rwpage {

    ::itcl::class SnigHome {
        inherit SnigPage

        private variable entities

        constructor {key} {SnigPage::constructor $key} { 
            set entities [list]
            $this title en "List of SNIG Entities" pt "List of SNIG Entities"
        }

        public method prepare_page {language argsqs} {

            set entities [::ngis::service::list_entities "%"]
            set entities [lmap e $entities {
                lassign $e eid description count
                set ent_form_url [::rivet::xml edit [list a href [::rivetweb::composeUrl viewent $eid]]]
                set ent_stats_url [::rivet::xml Statistics [list a href [::rivetweb::composeUrl statseid $eid]]]
                list $eid [::rivet::xml $description [list a href [::rivetweb::composeUrl eid $eid]]] $count \
                                                                                                $ent_form_url \
                                                                                                $ent_stats_url
            }]

        }

        public method print_content {language args} {
            #::rivet::parse rvt/entities.rvt
            set template_o  [::rivetweb::RWTemplate::template $::rivetweb::template_key]
            set ns [$template_o formatters_ns]
            puts [${ns}::entities_table $entities]
        }
    }
}

