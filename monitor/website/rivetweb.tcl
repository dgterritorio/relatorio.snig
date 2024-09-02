
set dot_idx [lsearch $auto_path "."]
if {$dot_idx <  0} { 
    set auto_path [concat "." $auto_path]
} else {
    set auto_path [concat "." [lreplace $auto_path $dot_idx $dot_idx]]
}
package require ngis::logger
package require ngis::configuration
package require ngis::roothandler
package require DIO 2.0
package require dio_Tdbc 2.0

::rivetweb::init Marshal top -nopkg

::ngis::conf init
