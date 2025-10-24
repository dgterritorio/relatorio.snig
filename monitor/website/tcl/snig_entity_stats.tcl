package require ngis::page
package require json
package require form
package require ngis::servicedb

namespace eval ::rwpage {
    ::itcl::class EntityStats {
        inherit SnigPage
        private variable report_n
        private variable eid
        private variable entities_d
        private variable report_queries_schema
        private variable sections_d
        private variable views_d
        private variable results_set

        # variable used to control the output
        private variable section_range
        private variable results_a

        constructor {key} {SnigPage::constructor $key} {
            array set results_a {}
            ::ngis::configuration::readconf report_queries_schema
            set results_set ""
            set views_d    [dict create 0 "_00_ungrouped_results"                           \
                                        1 "_01_group_urls_by_http_protocol"                 \
                                        2 "_02_group_by_http_status_code_global"            \
                                        4 "_04_group_by_http_status_code_and_domain"        \
                                        5 "_05_group_by_wms_capabilities_validity_global"   \
                                        6 "_06_group_by_wfs_capabilities_validity_global"   \
                                        7 "_07_group_by_wms_capabilities_validity_and_entity" \
                                        8 "_08_group_by_wfs_capabilities_validity_and_entity" \
                                        9 "_09_group_by_wms_capabilities_validity_and_domain" \
                                       10 "_10_group_by_wfs_capabilities_validity_and_domain" \
                                       11 "_11_group_by_wms_gdal_info_validity_global"      \
                                       12 "_12_group_by_wfs_ogr_info_validity_global"       \
                                       13 "_13_group_by_wms_gdal_info_validity_and_entity"  \
                                       14 "_14_group_by_wfs_ogr_info_validity_and_entity"   \
                                       15 "_15_group_by_wms_gdal_info_validity_and_domain"  \
                                       16 "_16_group_by_wfs_ogr_info_validity_and_domain"]

            set sections_d [dict create 1 [dict create description "HTTP Status Codes"      range [list 1 2 4]] \
                                        2 [dict create description "WMS Capabilities"       range [list 5 7 9]] \
                                        3 [dict create description "WFS Capabilities"       range [list 6 8 10]] \
                                        4 [dict create description "WMS GDAL_INFO Response" range [list 13 15]] \
                                        5 [dict create description "WFS OGR_INFO Response"  range [list 14 16]]]
 
        }

        public method is_authorized {eid} {
            return true
        }

        proc entity_query_select_form {form_response} {
            upvar 1 $form_response formdefaults

            set form [form [namespace current]::confirm_sub -method     POST                                \
                                                            -action     [::rivetweb::composeUrl stats $eid] \
                                                            -defaults   formdefaults                        \
                                                            -enctype    "multipart/form-data"]

            $form start
            set section_keys [lsort -integer [dict keys $sections_d]]
            $form select section -values $section_keys -labels [lmap k $section_keys { dict get $sections_d $k description }]
            $form hidden eid    -value $eid
            $form hidden stats  -value $eid
            $form submit submit -value "Query Data"
            $form end
            $form destroy
        }

        public method prepare_page {language argsqs} {
            $this title $language "[$this key]: [info object class $this]"
            set eid [dict get $argsqs stats]

            set args_posted [::rivet::var_post all]

            if {$results_set != ""} {
                catch { $results_set destroy }
                set results_set ""
            }
            array unset results_a

            if {[dict exists $args_posted section]} {
                if {[$this is_authorized $eid]} {
                    set dbhandle [$this get_dbhandle]
                    set section [dict get $args_posted section]
                    set section_range [dict get $sections_d $section range]

                    array unset results_a
                    foreach qi $section_range {
                        set results_l {}
                        set sql "SELECT * from ${report_queries_schema}.[dict get $views_d $qi] WHERE eid=$eid"
                        puts $sql
                        set results_set [$dbhandle exec $sql]
                        if {[$results_set error]} {

                        } else {
                            if {[$results_set numrows] > 0} {
                                while {[$results_set next -dict d]} {
                                    lappend results_l $d
                                }
                            } else {
                                #set results_a($qi) "No data"
                                continue
                            }
                        }
                        set results_a($qi) $results_l
                    }
                    $this close_dbhandle
                }
            }
        }

        public method print_content {language} {
            #set args_s [lmap {k v} [$this url_args] { list $k $v }]
            #puts [::rivet::xml "URL encoded: [join $args_s \n]" pre]
            #set args_s [lmap {k v} [::rivet::var_post all] { list $k $v }]
            #puts [::rivet::xml "POST encoded: [join $args_s \n]" pre]
            
            array set response_post [::rivet::var_post all]

            $this entity_query_select_form response_post

            set template_o [::rivetweb::RWTemplate::template $::rivetweb::template_key]
            set ns [$template_o formatters_ns]

            if {[llength [array names results_a]] > 0} {
                foreach qi $section_range {
                    set rows_l $results_a($qi)
                    set columns     [::ngis::reports::get_report_columns $qi [dict keys [lindex $rows_l 0]]]
                    #puts [::rivet::xml "columns = $columns" pre]
                    set captions    [::ngis::reports::get_captions $columns $language]
                    set table_body_rows [lmap r $rows_l { dict values [dict filter $r key {*}$columns] }]
                    set top_header "[::ngis::reports::get_table_header $qi] ($qi)"
                    #puts [::rivet::xml "qi = $qi" pre]
                    puts [${ns}::mk_table $captions $table_body_rows $top_header]
                }
            }
        }
    }
}
