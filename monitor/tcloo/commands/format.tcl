# format.tcl --
#
# sets the current session (connection) messaging protocol
#

namespace eval ::ngis::client_server {

    ::oo::class create Format {

        method exec {args} {
            if {[llength $args] == 0} {
                set fmt [$::ngis_server get_connection_format]
                if {$fmt != ""} {
                    return [list c104 $fmt]
                } else {
                    return [list c501 "Invalid or undefined protocol format"
                }
            }

            set fmt [lindex $args 0]
            switch -nocase $fmt {
                JSON -
                HR   { 
                    $::ngis_server set_connection_format [string toupper $fmt]
                    return [list c104 [$::ngis_server get_connection_format]]
                }
                default { return [list c113 $fmt] }
            }
        }

    }

    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd FORMAT cmd FORMAT has_args maybe description "Set/Query message format" help format.md]
        }
        proc mk_cmd_obj {} {
            return [::ngis::client_server::Format create ::ngis::clicmd::FORMAT]
        }
    }
}
