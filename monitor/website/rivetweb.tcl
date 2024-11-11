
foreach dot [list "." ".."] {
    set dot_idx [lsearch $auto_path $dot]
    if {$dot_idx <  0} { 
        set auto_path [concat $dot $auto_path]
    } else {
        set auto_path [concat $dot [lreplace $auto_path $dot_idx $dot_idx]]
    }
}
package require ngis::logger
package require ngis::configuration
package require ngis::roothandler
package require DIO 2.0
package require dio_Tdbc 2.0
package require ngis::protocol
package require ngis::conf

::rivetweb::init Marshal top -nopkg

::ngis::conf init
