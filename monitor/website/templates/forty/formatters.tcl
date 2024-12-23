package require ngis::common

proc entities_table {rows_l} {
    set captions_l [lmap t [list "eid" "entity definition" "service record"] { ::rivet::xml $t th }]
    set table_head_t "<thead><tr>[join $captions_l ""]</tr></thead>"

    set table_body_l [lmap r $rows_l {
        ::rivet::xml [join [lmap e $r { ::rivet::xml $e td }] ""] tr
    }]

    set table_body_t [::rivet::xml [join $table_body_l "\n"] tbody]

    return [::rivet::xml "${table_head_t}\n${table_body_t}" [list table class "table-wrapper"]]
}

proc entity_service_recs {rows_l entity_description} {
    set captions_l $::ngis::reports::report_a(122.capts)
    set captions_html_l [lmap t $::ngis::reports::report_a(122.capts) { ::rivet::xml $t th }]
    set table_head_t0 [::rivet::xml $entity_description tr [list td colspan [llength $captions_l]]]
    set table_head_t1 [::rivet::xml $captions_html_l ""



    return [::rivet::xml [$hr_formatter c122 $rows_l $entity_description] pre]
}
