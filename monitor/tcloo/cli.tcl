# command_line.tcl --
#
# This class is supposed to provide a structural
# solution to command parsing and dispatching
#

package require TclOO
package require ngis::conf
package require ngis::common
package require ngis::csprotomap

::oo::class create ::ngis::CLI {
    variable cli_cmds 
    variable docs_base
    variable cmds_list

    constructor {snig_monitor_dir} {
        set cli_cmds    [::ngis::ClientServerProtocolMap cli_map $snig_monitor_dir]
        set cmds_list   [lsort [dict keys $cli_cmds]]

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
                set cmd_found [lindex $cmds_list $list_idx]
                if {[string length $cmd_found] >= [string length $cli_cmd]} {
                    return [list OK $cmd_found [dict get $cli_cmds $cmd_found]]
                } else {
                    return [list ERR "Invalid $cli_cmd (should have been '${cmd_found}'?)"]
                }
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
            #set parsed_cmd [string toupper [lindex $clicmd 0]
            set cmd_args    [string range $cli_line $first_space+1 end]
        }

        # it's here where commands are forced to be uppercase before further command analysis
        # and eventual transmission to the server

        lassign [my SearchCommand [string toupper $parsed_cmd]] cmd_tree_result cmd_completed cmd_tree_result_value
        if {$cmd_tree_result == "OK"} {
            set command_d $cmd_tree_result_value
        } else {
            return [list $cmd_tree_result $cmd_completed]
        }        

        dict with command_d {
            set nargs [llength $cmd_args]

            # we first examine the case of special inner commands (method key existing)

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

                            set help_cmd [string toupper [string toupper $help_cmd]]

                            lassign [my SearchCommand $help_cmd] cmd_tree_result cmd_completed cmd_tree_result_value
                            #puts "cmd_tree_result: $cmd_tree_result, cmd_tree_result_value: $cmd_tree_result_value"
                            if {$cmd_tree_result != "OK"} {
                                #set help_cmd [dict get $cmd_tree_result_value cmd]
                                return [list ERR "Unrecognized command '$help_cmd'"
                            }

                            #puts "help_cmd: $cmd_completed"

                            if {[dict exists $cli_cmds $cmd_completed]} {
                                set help_file [file join $docs_base [dict get $cli_cmds $cmd_completed help]]
                                if {[file exists $help_file] && [file readable $help_file]} {

                                    # sed command to substitute symbols in the man pages

                                    set sed_cmd [list "sed" "-e s/@CMD@/$cmd_completed/g" \
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
