# -- view_entity.tcl
#
#
package require fileutil
package require form
package require ngis::entitymap

namespace eval ::rwpage {
    ::itcl::class ViewEntity {
        inherit SnigPage

        private variable fun
        private variable entity_d

        constructor {key} {SnigPage::constructor $key} { }

        public method prepare_page {language argsqs} {
            if {[string is false [::rwdatas::NGIS::is_logged]]} {
                ::rivet::redirect [::rivetweb::composeUrl]
            }
            set eid [dict get $argsqs viewent]
            set fun [::rivet::var_qs get fun print_form]
            ::rivet::load_response form_resp_a
            switch $fun {
                entity_update {
                    $this title $language "Update Entity Data"
                    ::ngis::entity_hash_map::update_entity [$this get_dbhandle] [array get form_resp_a]
                    $ngis::messagebox post_message "Data Updated"
                }
                regenerate_hash {
                    $this title $language "Entity Data Management and Hash Creation"
                    set hash [::ngis::entity_hash_map::generate_hash 16 {*}[array get form_resp_a]]
                    ::ngis::entity_hash_map::update_entity [$this get_dbhandle] [dict create eid $eid hash $hash]   
                    $ngis::messagebox post_message "Entity Hash Recreated"

                    set entity_d [::ngis::entity_hash_map::read_entity [$this get_dbhandle] $eid]

                    dict with entity_d {
                        set website   [::ngis::configuration readconf website]
                        set stats_url "${website}[::rivetweb::composeUrl stats $hash]"
                        set msg [string map [list ENTITY_NAME $description \
                                                  ENTITY_STATS_URL $stats_url] \
                                                [::fileutil::cat generic/new_hash_message_template.txt]]

                        set ws_global_st [::ngis::configuration readconf website_global_status]

                        set hash_count 0
                        if {[[$this get_dbhandle] fetch $website ws_status -table $ws_global_st -keyfield hostname]} {
                            set hash_count $ws_status(hash_regenerate_count)
                            set hash_message_filename [file join [::ngis::configuration::readconf message_files_dir] \
                                                                       "${hash_count}-${eid}.txt"]

                            fileutil::writeFile $hash_message_filename $msg
                            [$this get_dbhandle] exec "UPDATE $ws_global_st set hash_regenerate_count = hash_regenerate_count + 1"
                        } else {
                            return -code error -errorcode error_create_entity_hash "Error reading website status"
                        }
                    }

                }
                print_form -
                default {
                    $this title $language "Update Entity Data"
                }
            }
            set entity_d [::ngis::entity_hash_map::read_entity [$this get_dbhandle] $eid]
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

