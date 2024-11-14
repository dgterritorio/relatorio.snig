# command_line.tcl --
#
# This class is supposed to provide a structural
# solution to command parsing and dispatching
#

package require TclOO
package require ngis::conf
package require ngis::common

::oo::class create ::ngis::CLI {
    variable cli_cmds 
    variable docs_base
    variable cmds_list

    constructor {} {
        set cli_cmds [dict create  \
                    CHECK   [dict create cmd CHECK     has_args yes   description "Starts Monitoring Jobs" help check.md] \
                    ENTITIES [dict create cmd ENTITIES  has_args maybe description "List Entities" help le.md] \
                    FORMAT  [dict create cmd FORMAT    has_args maybe description "Set/Query message format" help format.md] \
                    JOBLIST [dict create cmd JOBLIST   has_args maybe description "List Running Jobs" help jl.md] \
                    REGTASK [dict create cmd REGTASKS  has_args no    description "List registered tasks" help lt.md ] \
                    RUNSEQ  [dict create cmd QUERY     has_args no    description "Query Sequence Execution Status" help qs.md] \
                    STOP    [dict create cmd STOP      has_args no    description "Stop Monitor Operations" help stop.md] \
                    SHUT    [dict create cmd EXIT      has_args no    description "Immediate Client and Server termination" help sx.md] \
                    TASKRES [dict create cmd QTASK     has_args yes   description "Display Task results" help tsk.md] \
                    SERVICE [dict create cmd QSERVICE  has_args yes   description "Query Service Data" help url.md] \
                    X       [dict create cmd X         has_args no    description "Exit client" help x.md method stop_client] \
                    WHOS    [dict create cmd WHOS      has_args no    description "List Active Connections" help w.md] \
                    ZZ      [dict create cmd ZZ        has_args yes   description "Send custom messages to the server" \
                                                                      method send_custom_cmd help zz.md] \
                    HELP    [dict create cmd ?         has_args maybe  description "List CLI Commands" \
                                                                      method cli_help help help.md]]

        set cmds_list [lsort [dict keys $cli_cmds]]

        set docs_base $::ngis::docs_base
    }

    method print_help_menu {} {
        foreach clicmd [lsort [dict keys $cli_cmds]] {
            dict with cli_cmds $clicmd {
                puts [format "%-10s: %s" $clicmd $description]
            }
        }
    }

    method SearchCommand {cli_cmd} {

        # we first try to resolve the command as an alias

        set cli_cmd [::ngis::CLIAliases resolve_alias $cli_cmd]

        # unefficiently (we need a struct::tree for this!) but effectively 
        # we identify shortened forms of a command and in case autocomplete it,
        # otherwise we return the 'command not found' error

        set nch 0
        while {1} {
            set truncated [string range $cli_cmd 0 $nch]
            set list_idx  [lsearch -glob -all $cmds_list "${truncated}*"]
            set n_idx     [llength $list_idx]
            if {$n_idx == 0} {
                return [list ERR "Command '$cli_cmd' not found"]
            } elseif {$n_idx == 1} {
                return [list OK [dict get $cli_cmds [lindex $cmds_list $list_idx]]]
            } else {
                incr nch
            }

            # an incomplete and ambigous command leads to
            # substring exaustion without unique indentification

            if {$nch >= [string length $cli_cmd]} {
                return [list ERR "Command '$cli_cmd' ambiguous or not found"]
            }
        }

    }

    method dispatch {cli_line} {
        set first_space [string first " " $cli_line]
        if {$first_space < 0} {
            set parsed_cmd $cli_line
            set cmd_args   ""
        } else {
            set parsed_cmd  [string range $cli_line 0 $first_space-1]
            #set parsed_cmd  [string toupper [lindex $clicmd 0]
            set cmd_args    [string range $cli_line $first_space+1 end]
        }

        lassign [my SearchCommand [string toupper $parsed_cmd]] cmd_tree_result cmd_tree_result_value
        if {$cmd_tree_result == "OK"} {
            set command_d $cmd_tree_result_value
        } else {
            return [list $cmd_tree_result $cmd_tree_result_value]
        }        

        dict with command_d {
            set nargs [llength $cmd_args]

            # we first examine the case of special inner commands (protocol command cmd = "")

            if {[dict exists $command_d method]} {
                switch $method {
                    send_custom_cmd {
                        return [list OK [concat $parsed_cmd $cmd_args]]
                    }
                    cli_help {
                        if {[llength $cmd_args] == 0} {
                            my print_help_menu
                        } else {
                            lassign $cmd_args help_cmd

                            # we have to search the command

                            lassign [my SearchCommand [string toupper $help_cmd]] cmd_tree_result cmd_tree_result_value
                            if {$cmd_tree_result == "OK"} {
                                set help_cmd [dict get $cmd_tree_result_value cmd]
                            } else {
                                return [list ERR "Unrecognized command '$help_cmd'"
                            }

                            if {[dict exists $cli_cmds $help_cmd]} {
                                set help_file [file join $docs_base [dict get $cli_cmds $help_cmd help]]
                                if {[file exists $help_file] && [file readable $help_file]} {

                                    # sed command to substitute symbols in the man pages

                                    set sed_cmd [list   "sed" "-e s/@CMD@/$help_cmd/g" \
                                                        "-e s/@AUTHOR@/[string map [list " " "\\ "] ${::ngis::authorship}]/g" \
                                                        "-e s%@BUG_REPORTS@%${::ngis::bug_reports}%g"]
                                    set sed_cmd [join $sed_cmd " "]

                                    # pulling everything together: cat -> sed -> pandoc (to nroff format) -> man (to print)

                                    set execcmd [list "cat $help_file" $sed_cmd \
                                                      "pandoc -s -f markdown -t man -" \
                                                      "man -l - 2> /dev/null"]

                                    puts [exec -ignorestderr {*}[join $execcmd " | "]]
                                } else {
                                    puts "File '$help_file' not found"
                                }
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
                }
                return [list OK $cmd $cmd_args]
            }
        }
    }
}

package provide ngis::cli 0.1
