package require syslog

namespace eval ::ngis {
    variable nmsg -1

    proc log {mesg {severity "info"}} {
        variable nmsg

        set mesg "[incr nmsg] - $mesg"

        if {[info exists ::tcl_interactive] && $::tcl_interactive} {
            syslog -perror -ident ngis_site -facility user info $mesg
        } else {
            syslog -ident ngis_site -facility user info $mesg
        }
    }

    proc reset {} {
        variable nmsg
        set nmsg 0
    }

    namespace export log reset
    namespace ensemble create
}

package provide ngis::logger 0.1

