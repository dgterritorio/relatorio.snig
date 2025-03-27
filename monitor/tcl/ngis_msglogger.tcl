# ngis_msglogger.tcl --
#
#
#

package require syslog
package require ngis::conf

namespace eval ::ngis::logger {
    variable nmsg -1

    proc emit {mesg} {
        variable nmsg

        set mesg "[incr nmsg] - $mesg"

        if {[info exists ::tcl_interactive] && $::tcl_interactive} {
            syslog -perror -ident snig -facility user info $mesg
        } else {
            syslog -ident snig -facility user info $mesg
        }
    }

    proc debug {mesg} {
        if {$::ngis::debugging} {
            emit $mesg
        }
    }

    proc reset {} {
        variable nmsg
        set nmsg 0
    }

    namespace export emit reset debug
    namespace ensemble create
}

package provide ngis::msglogger 0.1
