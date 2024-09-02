#
# -- termio.tcl
#
# simple general purpose stdin prompt 
#
#

namespace eval termio {

# -- get_input
#
#

    proc get_input {{prompt ""} {default_v ""} {empty_string "--no-empty-input"}} {
        if {$default_v != ""} {
            set prompt "$prompt \[$default_v\]: "
        } else {
            set prompt "$prompt "
        }
        set line ""

        while {1} {
            puts -nonewline $prompt
            flush stdout
            set line [gets stdin]

            # EOF causes the procedure to return an empty string

            if {[eof stdin]} {
                puts ""
                incr ::client_event_loop_variable
                return ""
            }

            if {($line == "")} {
                
                if {$default_v != ""} {
                    return $default_v
                } elseif {$empty_string == "--allow-empty-input"} {
                    return $line
                }

            } else {
                break
            }
        }

        return $line
    }
    namespace export get_input

}

package provide termio 1.1
