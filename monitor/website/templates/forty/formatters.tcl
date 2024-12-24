package require ngis::common
package require ngis::utils

proc mk_table {table_captions_l table_body_rows_l {top_cap ""} {html_attributes_l ""}} {

    set nrows       [llength $table_body_rows_l]
    set ncolumns    [llength [lindex $table_body_rows_l 0]]
    if {$html_attributes_l == ""} {
        set html_attributes_l [lrepeat $nrows [lrepeat $ncolumns ""]]
    }

    if {[string length [string trim $top_cap]] > 0} {
        set top_cap_html [::rivet::xml $top_cap tr [list th colspan [llength $table_captions_l]]]
    } else {
        set top_cap_html ""
    }

    set captions_html_l [lmap t $table_captions_l { ::rivet::xml $t th }]
    set table_head_html ""
    if {[llength $captions_html_l] > 0} {
        set table_head_html "<thead>${top_cap_html}[join $captions_html_l ""]</thead>"
    }

    set table_body_l [lmap r $table_body_rows_l r_attr $html_attributes_l {
        ::rivet::xml [join [lmap e $r c_attr $r_attr {

            ::rivet::xml $e [list td {*}$c_attr]

        }] ""] tr
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

proc service_table {service_d} {

    set legend_d [::ngis::reports::c116legend]
    set service_fields_l {gid uuid description entity_definition uri uri_type version}
    set service_table_l [lmap f $service_fields_l {
        if {![dict exists $service_d $f]} {
            dict set service_d $f ""
        }
        list [dict get $legend_d $f] [::rivet::wrapline [dict get $service_d $f] 100 -html]
    }]

    set description [dict get $service_d description]
    set css_classes_l {}
    if {[dict exists $service_d tasks]} {
        set tasks_d [dict get $service_d tasks]
        set task_t [lmap t $::ngis::registered_tasks {
            lassign $t task procedure tdescr filename language
            if {[dict exists $tasks_d $task]} {
                set tasks_data  [dict get $tasks_d $task]
                set exit_status [dict get $tasks_data exit_status]
                lappend css_classes_l "task${exit_status}"

                list $tdescr $exit_status [dict get $tasks_data exit_info] [dict get $tasks_data ts]
            } else {
                continue
            }
        }]
    }

    # now we transform the css_classes_l in a "table" (actually a list of lists)
    # in the same form of the table's data

    set css_classes_tb [lmap css_class $css_classes_l {
        list "" [list class $css_class] "" ""
    }]

    set t1 [mk_table {} $service_table_l]
    set t2 [mk_table {*}$::ngis::reports::report_a(118.capts) $task_t \
                     "\[118\] [dict get $service_d description]" $css_classes_tb]

    return "$t1 \n $t2"
}
