# -- view_entity.tcl
#
#
package require form
package require ngis::entitymap

namespace eval ::rwpage {
    ::itcl::class ViewEntity {
        inherit SnigPage

        private variable fun
        private variable entity_d

        constructor {key} {SnigPage::constructor $key} { }

        public method prepare_page {language argsqs} {
            set eid [dict get $argsqs viewent]
            set fun [::rivet::var_qs get fun print_form]
            ::rivet::load_response form_resp_a
            #::rivet::parray form_resp_a
            switch $fun {
                entity_update {
                    dict set ::ngis::entity_hash_map::entities_d $eid email $form_resp_a(email)
                    dict with ::ngis::entity_hash_map::entities_d $eid {
                        $ngis::messagebox post_message "Email updated for entity '$description'"
                    }
                    $this title $language "Update Entity Data"
                }
                print_form -
                default {
                    $this title $language "Update Entity Data"
                }
            }
            set entity_d [dict get $::ngis::entity_hash_map::entities_d $eid]
        }

        public method print_content {language} {
            switch $fun {
                print_form -
                default {
                    ::rivet::parse rvt/entity_form.rvt
                }
            }
        }

    }
}

