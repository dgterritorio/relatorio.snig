
proc entities_table {rows_l} {
    set html_rows_l {}
    foreach r $rows_l {
        lassign $r gid descr uri

        set uri_d [uri::split $uri]
        set host ""
        if {[dict exists $uri_d host]} {
            set host [dict get $uri_d host]
        }

        if {[string length $descr] > 80} {
            set descr "[string range $descr 0 76]..."
        }
        lappend html_rows_l [::rivet::xml [join [list [::rivet::xml $gid td] \
                                                      [::rivet::xml $descr td] \
                                                      [::rivet::xml $host td [list a href $uri]]] ""] tr]
    }
    return [::rivet::xml "<tr><th>gid</th><th>Description</th><th>Host</th></tr>[join $html_rows_l \n]" [list table class table]]

}
