package require uri
package require fileutil

::rivet::apache_log_error info "auto_path: $auto_path"

package require ngis::configuration
package require MessagePrinter
package require ngis::logger
package require ngis::roothandler
package require ngis::login
package require ngis::page
package require Session
package require ngis::servicedb
package require Thread
package require ngis::ancillary_io_thread
package require ngis::ancillary_io
package require json
package require ngis::common

::rivetweb::init Marshal top -nopkg
::rivetweb::init Login   top -nopkg

set snig_header [exec /usr/bin/figlet "S.N.I.G."]

set ::rivetweb::handler_script [fileutil::cat [file join $rweb_root tcl before.tcl]]

namespace eval ::ngis {
    variable registered_tasks
    variable cssprogressive
    variable jquery_url
    variable messagebox
    # define the web server jQuery path

    set jquery_host [::ngis::configuration readconf jquery_root]
    set jquery_uri  [::ngis::configuration readconf jquery_uri]
    set jquery_url  [join [list $jquery_host $jquery_uri] "/"]

    ::rivet::apache_log_error info "jQuery path formed from '$jquery_host' and '$jquery_uri'"
    
    # defining the production system cssprogressive counter

    set cssprogressive [::ngis::configuration readconf cssprogressive]

    # starting the ancillary thread

    namespace eval ancillary {
        variable thread_id
    }

    set ancillary::thread_id [ancillary::thread_init]

    set registered_tasks [ancillary::connection_init $ancillary::thread_id]
    set messagebox [MessagePrinter [namespace current]::#auto]

}
::rivet::apache_log_error info "rivetweb.tcl successfully terminates"
