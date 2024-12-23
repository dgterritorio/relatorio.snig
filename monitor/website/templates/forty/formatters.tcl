package require ngis::common
package require ngis::utils

proc mk_table {table_captions_l table_body_rows_l {top_cap ""}} {
    if {[string length [string trim $top_cap]] > 0} {
        set top_cap_html [::rivet::xml $top_cap tr [list th colspan [llength $table_captions_l]]]
    } else {
        set top_cap_html ""
    }

    set captions_html_l [lmap t $table_captions_l { ::rivet::xml $t th }]
    set table_head_html "<thead>${top_cap_html}[join $captions_html_l ""]</thead>"

    set table_body_l [lmap r $table_body_rows_l {
        ::rivet::xml [join [lmap e $r { ::rivet::xml $e td }] ""] tr
    }]
    set table_body_html [::rivet::xml [join $table_body_l "\n"] tbody]
    return [::rivet::xml "${table_head_html}\n${table_body_html}" [list table class "table-wrapper"]]
}

proc entities_table {rows_l} {
    return [mk_table [list "eid" "entity definition" "service record"] $rows_l ""]
}

proc entity_service_recs {rows_l entity_description} {
    set services_t [lmap s $rows_l {
        dict with s {
            set uri_d   [::uri::split $uri]
            set host    [dict get $uri_d host]

            if {![info exists version]} { set version "" }
            set r [list $gid [::ngis::utils::string_truncate $description 60] $host $uri_type $version]
        }
        set r
    }]
    return [mk_table {*}$::ngis::reports::report_a(122.capts) $services_t "\[122\] $entity_description"]
}
