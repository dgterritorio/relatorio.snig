package require ngis::page
package require json
package require form

namespace eval ::rwpage {
    ::itcl::class EntityStats {
        inherit SnigPage
        private variable report_n
        private variable eid
        private variable entities_d
        private variable queries_d
        private variable report_queries_schema
        private variable sections_d

        constructor {key} {SnigPage::constructor $key} {
            ::ngis::configuration::readconf report_queries_schema
            set entities_d [dict create]
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

        proc print_form {eid} {
            set form [form [namespace current]::confirm_sub -method     GET \
                                                            -action     [::rivetweb::composeUrl stats $eid] \
                                                            -defaults   registration \
                                                            -enctype    "multipart/form-data"]

            $form start


            set section_keys [lsort -integer [dict keys $sections_d]]
            $form select section -values $section_keys -labels [lmap k $section_keys { dict get $sections_d $k description }]
            $form end
            $form destroy
        }

        public method prepare_page {language argsqs} {
            $this title $language "[$this key]: [info object class $this]"
            set eid [dict get $argsqs stats]
        }

        public method print_content {language} {
            $this print_form $eid
        }
    }
}
