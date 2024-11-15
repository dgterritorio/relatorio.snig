# CLIMap
#
# Keeps a database of cli and protocol commands
#
#

namespace eval ::ngis::ClientServerProtocolMap {
    variable cli_cmds

    set cli_cmds [dict create  \
                CHECK   [dict create cmd CHECK     has_args yes   description "Starts Monitoring Jobs" help check.md] \
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
                HELP    [dict create cmd ?         has_args maybe description "List CLI Commands" \
                                                                  method cli_help help help.md]]


    proc build_proto_map {} {
        set cs_map_d [dict create]

        set cmd_flist [glob [file join tcloo commands *.tcl]]
        foreach f $cmd_flist {
            source $f

            set cmd_obj [::ngis::client_server::tmp::mk_cmd_obj]
            dict set cs_map_d [namespace tail $cmd_obj] $cmd_obj
        }
        namespace delete ::ngis::client_server::tmp
        return $cs_map_d
    }

    proc cli_map {} {
        variable cli_cmds
        
        set cmd_flist [glob [file join tcloo commands *.tcl]]
        foreach f $cmd_flist {
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
