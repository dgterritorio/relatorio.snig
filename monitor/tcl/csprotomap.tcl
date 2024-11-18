# CLIMap
#
# Keeps a database of cli and protocol commands
#
#

namespace eval ::ngis::ClientServerProtocolMap {
    variable cli_cmds
    variable verbose    false

    set cli_cmds [dict create  \
            STOP        [dict create cmd STOP      has_args no    description "Stop Monitor Operations" help stop.md] \
            SHUTDOWN    [dict create cmd SHUTDWN   has_args no    description "Immediate Client and Server termination" help sx.md] \
            EXIT        [dict create cmd EXIT      has_args no    description "Exit client" help x.md method stop_client] \
            ZZ          [dict create cmd ZZ        has_args yes   description "Send custom messages to the server" \
                                                              method send_custom_cmd help zz.md] \
            HELP        [dict create cmd ?         has_args maybe description "List CLI Commands" method cli_help help help.md]]


    proc process_args {args} {
        variable verbose

        while {[llength $args] > 0} {
            set args [lassign $args a]
            if {$a == "-verbose"} {
                set args [lassign $args v]
                set verbose [string is true $v]
            }
        }

    }

    proc build_proto_map {monitor_dir args} {
        variable verbose

        process_args {*}$args

        set cs_map_d [dict create]

        set cmd_flist [glob [file join $monitor_dir tcloo commands *.tcl]]
        foreach f $cmd_flist {
            if {$verbose} { puts "sourcing $f" }
            source $f

            set cmd_obj [::ngis::client_server::tmp::mk_cmd_obj]
            dict set cs_map_d [namespace tail $cmd_obj] $cmd_obj
        }
        namespace delete ::ngis::client_server::tmp
        return $cs_map_d
    }

    proc cli_map {monitor_dir args} {
        variable verbose
        variable cli_cmds
        
        set cmd_flist [glob [file join $monitor_dir tcloo commands *.tcl]]
        foreach f $cmd_flist {
            if {$verbose} { puts "sourcing $f" }
            source $f

            set cmd_d [::ngis::client_server::tmp::identify]
            set cli   [dict get $cmd_d cli_cmd]
            dict unset cmd_d cli_cmd
            dict set cli_cmds $cli $cmd_d
        }
        namespace delete ::ngis::client_server::tmp
        return $cli_cmds
    }

    namespace export *
    namespace ensemble create
}

package provide ngis::csprotomap 1.0
