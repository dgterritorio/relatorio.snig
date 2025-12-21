# Print the call stack (excluding this proc's own frame).
# For each frame, show "level procName arg1 arg2 ..."
package require syslog

proc dump_stack {} {
    set top [info level]
    syslog -ident snig -facility user info "=== Call Stack ==="
    for {set lvl 2} {$lvl <= $top} {incr lvl} {
        # Words of the command as it was invoked at this level
        set words [info level $lvl]

        # Prefer the canonical proc name from [info frame], if available
        set name ""
        if {![catch {info frame $lvl} frameDict] && [dict exists $frameDict proc]} {
            set name [dict get $frameDict proc]
        } else {
            set name [lindex $words 0]
        }

        # The actual argument values as a Tcl list
        set args [lrange $words 1 end]

        # Print one line per frame
        syslog -ident snig -facility user info [format "#%d %s %s" $lvl $name [list {*}$args]]
    }
}

