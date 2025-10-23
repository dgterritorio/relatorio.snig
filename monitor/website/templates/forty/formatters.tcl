package require ngis::common
package require ngis::utils

proc mk_table {table_captions_l table_body_rows_l {top_cap ""} {html_attributes_l ""} {table_html_attrs ""}} {

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
    return [::rivet::xml "${table_head_html}\n${table_body_html}" [list table class "table-wrapper" {*}$table_html_attrs]]

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
            if {![info exists description]} { set description "undefined description" }
            set r [list $gid $description $host $uri_type $version]
        }
        set r
    }]
    return [mk_table {*}$::ngis::reports::report_a(122.capts) $services_t "\[122\] $entity_description"]
}

proc service_info {service_d} {

    set legend_d [::ngis::reports::c116legend]
    set service_fields_l {gid uuid description entity_definition uri uri_type version}
    set service_table_l [lmap f $service_fields_l {
        if {![dict exists $service_d $f]} {
            dict set service_d $f ""
        }
        list [dict get $legend_d $f] [::rivet::wrapline [dict get $service_d $f] 100 -html]
    }]
    return [mk_table {} $service_table_l]

}

proc service_tasks {service_d} {

    set css_classes_l {}
    set task_t {}
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

    return [mk_table {*}$::ngis::reports::report_a(118.capts) $task_t \
                     "\[118\] [dict get $service_d description]" $css_classes_tb]
}

proc service_table {service_d} {

    set t1 [service_info $service_d]
    set t2 [service_tasks $service_d]

    return "$t1 \n <div id=\"task_results\">$t2</div>"
}

proc generate_banner {language menu} {
    set links [$menu links]
    set links_l [lmap l $links {
        set owner   [$l link_owner]
        set href    [[$owner to_url $l] attribute href]
        set text    [$l link_text $language]
        set ltext   [::rivet::xml $text li [list a href $href]]
    }]

    return [::rivet::xml [join $links_l "\n"] [list nav id "menu"] [list ul class "links"]]
}

proc navigation_bar {rowcount urls} {
    set links_l [lmap symb [list \u00ab \u2039 \u203A \u00bb] u $urls {
        if {$u == ""} {
            ::rivet::xml $symb td
        } else {
            ::rivet::xml $symb td [list a href $u]
        }
    }]

    return [::rivet::xml [join $links_l ""] [list div id "navbar"] table tr]
}

proc display_report {report_n data_ld} {

    switch $report_n {
        112 {
            set connections_l {}
            foreach conn_d $data_ld {
                dict with conn_d {
                    lappend connections_l [list $login $type $ncmds $protocol $idle]
                }
            }

            return [mk_table {*}$::ngis::reports::report_a(112.capts) $connections_l \
                             "\[112\] SNIG Server Connections"]
        }
        114 {
            set jobs_l {}
            foreach job_d $data_ld {
                dict with job_d {
                    set elapsed_time [::ngis::utils::delta_time_s [expr [clock seconds] - $timestamp]]
                    set service_rec_link [::rivet::xml $description [list a href [::rivetweb::composeUrl service $gid]]]
                    lappend jobs_l [list $gid $service_rec_link $type $version $status $elapsed_time]
                }
            }

            if {[llength $jobs_l] > 0} {
                return [mk_table {*}$::ngis::reports::report_a(114.capts) $jobs_l "\[114\] Jobs Running"]
            } else {
                return [::rivet::xml "\[114\] No Jobs Running" div]
            }            
        }
    }

}

proc report_page {} {
    return [join [list [::rivet::xml "" [list div id report]] [::rivet::xml "" [list pre id response]]] "\n"]
}

proc message_box {message_l} {
    if {[llength $message_l] > 0} {
        set html_items [lmap m $message_l {
            lassign $m msgtxt severity
            switch $severity {
                error {
                    set cssclass "msgerror"
                } 
                default {
                    set cssclass "msginfo"
                }
            }

            ::rivet::xml $msgtxt [list li class $cssclass]
        }]

        return [::rivet::xml [join $html_items "\n"] ul]
    }
    return ""
}

