# -- reports.tcl
#
# Reports data need reformatting and tables need
# meaningful captions, whereas some columns don't
# need to be shown
#
# 

namespace eval ::ngis::reports {
    variable default_language   en
    variable captions_d [dict create]
    variable views_d [dict create    0 "_00_ungrouped_results"                           \
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

    variable sections_d [dict create 1 [dict create description "HTTP Status Codes"      range [list 1 2 4]]    \
                                     2 [dict create description "WMS Capabilities"       range [list 5 7 9]]    \
                                     3 [dict create description "WFS Capabilities"       range [list 6 8 10]]   \
                                     4 [dict create description "WMS GDAL_INFO Response" range [list 13 15]]    \
                                     5 [dict create description "WFS OGR_INFO Response"  range [list 14 16]]]

    variable table_headers_d [dict create   1   "Protocols" \
                                            2   "Returned HTTP Status Codes" \
                                            4   "Returned HTTP Status Codes By Domain/Host Name" \
                                            5   "WMS Capabilities Test Results" \
                                            6   "WFS Capabilities Test Results" \
                                            7   "WMS Capabilities Validity" \
                                            8   "WFS Capabilities Validity" \
                                            9   "WMS Capabilities Validity by Domain/Host Name" \
                                            10  "WMS Capabilities Validity by Domain/Host Name" \
                                            13  "WMS GDAL Info Response" \
                                            14  "WFS OGR Info Response" \
                                            15  "WMS GDAL Info Response by Domain/Host Name" \
                                            16  "WFS OGR Info Response By Domain/Host Name" \
    ]


# status_code dovrebbe in modo consistente essere il risultato 
# della traduzione della colonna service_status.exit_info

    proc init {} {
        variable captions_d

        set captions_en [dict   create \
                                status_code            "HTTP Status or Error"  \
                                status_code_definition "Status Code Definition" \
                                count                  "Count"                  \
                                ping_average           "Ping Average Time (secs.)" \
                                uri_domain             "URL Host"               \
                                result_message         "Result Description"     \
                                result_code            "Result Code"            \
                                entity                 "Entity"]

        dict set captions_d en $captions_en
    }

    proc get_captions {columns {language "en"}} {
        variable captions_d

        if {![dict exists $captions_d $language]} { set language en }
        set captions [lmap c $columns {
            if {[dict exists $captions_d $language $c]} {
                set cpt [dict get $captions_d $language $c]
            } else {
                set cpt $c
            }
            set cpt
        }]
        return $captions
    }

    proc get_report_columns {report columns_l} {
        variable reports_d

        if {$report == 1} {
            return [list url_start count]
        } elseif {$report == 2} {
            return [list status_code status_code_definition count ping_average]
        } elseif {$report == 4} {
            return [list uri_domain status_code status_code_definition count ping_average]
        } elseif {$report in [list 9 10 15]} {
            return [list uri_domain result_code result_message count ping_average]
        } elseif {$report in [list 5 6 7 8 11 12 13 14 16]} {
            return [list result_code result_message count ping_average]
        } else {
            return $columns_l
        }
    }

    proc get_table_header {qi} {
        variable table_headers_d

        if {[dict exists $table_headers_d $qi]} {
            return [dict get $table_headers_d $qi]
        }
        return ""
    }

    proc get_section {sect_n} {
        variable sections_d
        if {[dict exists $sections_d $sect_n]} {
            return [dict get $sections_d $sect_n]
        }
        return -code error -errorcode invalid_query_section "Invalid Report Query Section"
    }
}


package provide ngis::reports 1.0
