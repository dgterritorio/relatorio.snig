# command_line.tcl --
#
# This class is supposed to provide a structural
# solution to command parsing and dispatching
#

package require TclOO

::oo::class create ::ngis::CLI {
    variable cli_cmds 

    constructor {} {
        set cli_cmds [dict create  \
        LT [dict create cmd REGTASKS has_args no    description "List registered tasks" help lt.md ] \
        LE [dict create cmd ENTITIES has_args maybe description "List Entities" help le.md] \
        C  [dict create cmd CHECK    has_args yes   description "Run Monitor Jobs" help check.md] \
        F  [dict create cmd FORMAT   has_args maybe description "Set/Query message format" help format.md] \
        Q  [dict create cmd QUERY    has_args no    description "Query Monitor Status" help q.md] \
        T  [dict create cmd STOP     has_args no    description "Stop Monitor Operations" help stop.md] \
        SX [dict create cmd EXIT     has_args no    description "Terminate Monitor and Server" help sx.md] \
        X  [dict create cmd ""       has_args no    description "Exit client" help x.md method stop_client] \
        W  [dict create cmd WHOS     has_args no    description "List Active Connections" help w.md] \
        ZZ [dict create cmd ""       has_args yes   description "Send custom messages to the server" \
                                                    method send_custom_cmd help zz.md] \
        ?  [dict create cmd ""       has_args maybe description "List CLI Commands" \
                                                    method print_help_menu help help.md]]
    }

    method print_help_menu {} {
        foreach clicmd [lsort [dict keys $cli_cmds]] {
            dict with cli_cmds $clicmd {
                puts [format "%-10s: %s" $clicmd $description]
            }
        }
    }

    method dispatch {clicmd args} {
        set parsed_cmd  [string toupper [lindex $clicmd 0]]
        set cmd_args    $args
        #puts $cmd_args

        if {[dict exists $cli_cmds $parsed_cmd]} {
            dict with cli_cmds $parsed_cmd {
                set nargs [llength $cmd_args]
                if {$cmd == ""} {
                    switch $method {
                        send_custom_cmd {
                            return [list OK [concat $parsed_cmd $cmd_args]]
                        }
                        print_help_menu {
                            if {[llength $cmd_args] == 0} {
                                my print_help_menu
                            } else {
                                lassign $cmd_args help_cmd
                                if {[dict exists $cli_cmds $help_cmd]} {
                                    set help_file [file join doc [dict get $cli_cmds $help_cmd help]]
                                    exec cat $help_file | sed s/@CMD@/$parsed_cmd/g | pandoc - | w3m -T 'text/html' -dump
                                } else {
                                    puts "unrecognized command '$help_cmd'"
                                }
                            }
                        }
                        stop_client {
                            return EXIT
                        }
                    }
                } else {
                    if {$nargs == 0} {
                        if {$has_args == "yes"} {
                            return [list ERR "Missing arguments"]
                        }
                        return [list OK $cmd $cmd_args]
                    }
                    return [list OK $cmd $cmd_args]
                }
            }
        } else {
            return [list ERR "Command '$parsed_cmd' not found"]
        }
    }
}

package provide ngis::cli 0.1
