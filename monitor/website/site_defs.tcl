
foreach dot [list "." ".."] {
    set dot_idx [lsearch $auto_path $dot]
    if {$dot_idx < 0} {
        set auto_path [concat $dot $auto_path]
    } else {
        set auto_path [concat $dot [lreplace $auto_path $dot_idx $dot_idx]]
    }
}

package require ngis::configuration

namespace eval ::rivetweb {
    set default_template    [::ngis::configuration readconf template]
    set default_lang        en
}
