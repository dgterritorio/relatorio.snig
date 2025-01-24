# readconf.tcl --
#
# configuration accessor procedure
#

namespace eval ::ngis::configuration {
    variable confnamespace   [namespace current]

    proc readconf {confpar {confparvar ""}} {
        variable confnamespace

        if {$confparvar != ""} {
            upvar $confparvar v 
        } else {
            upvar $confpar v
        }

        set conf_varname "${confnamespace}::${confpar}"

        if {[info exists $conf_varname]} {
            set v [set $conf_varname]
        } else {
            return -code error -errocode conf_parameter_not_found "Configuration parameter '$confpar' not found"
        }

        return $v
    }
    namespace export readconf
    namespace ensemble create
}
package provide ngis::readconf 1.0
