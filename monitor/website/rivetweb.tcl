

::rivet::apache_log_error info "auto_path: $auto_path"

package require ngis::logger
package require ngis::configuration
package require ngis::roothandler
package require DIO 2.0
package require dio_Tdbc 2.0
package require ngis::protocol
package require ngis::conf

::rivetweb::init Marshal top -nopkg

set snig_header [exec /usr/bin/figlet "S N I G"]


::ngis::conf init
