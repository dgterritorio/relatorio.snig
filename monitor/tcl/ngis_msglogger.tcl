package require syslog

namespace eval ::ngis::logger {
    variable nmsg -1

    proc emit {mesg} {
        variable nmsg

        set mesg "[incr nmsg] - $mesg"

        if {[info exists ::tcl_interactive] && $::tcl_interactive} {
            syslog -perror -ident snig_monitor -facility user info $mesg
        } else {
            syslog -ident snig_monitor -facility user info $mesg
        }
    }

    proc reset {} {
        variable nmsg
        set nmsg 0
    }

    namespace export emit reset
    namespace ensemble create
}

package provide ngis::msglogger 0.1
