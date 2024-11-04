# formatters.tcl
#
# formatters run within the template namespace and provide template
# specific formatting of data

# assuming we have already loaded ngis::protocol, which in turn create
# instances of ngis::HRFormat and ngis::JSONFormat

proc entities_table {rows_l} {

    set out "<pre>"
    foreach r $rows_l {
        lassign $r gid descr uri

        set uri_d [uri::split $uri]

        set host ""
        if {[dict exists $uri_d host]} {
            set host [::rivet::xml [dict get $uri_d host] [list a href $uri]]
        }

        if {[string length $descr] > 80} {
            set descr "[string range $descr 0 76]..."
        }
        append out [format "%4s %80s %25s\n" $gid $descr $host]
    }
    append out "</pre>"
    return $out
}
