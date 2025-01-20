# protocol.tcl --
#
# The server creates an instance of protocol for each connection
# The overhead of doing this is justified by the small number of
# connections simultaneously open on the server with the benefit of
# not keeping track of a session state
#
#

package require ngis::common
package require ngis::csprotomap
package require ngis::hrformat
package require ngis::jsonformat
package require uri

oo::class create ngis::Protocol

oo::define ngis::Protocol {
    variable formatter
    variable CodeMessages
    variable ds_nseq
    variable nseq
    variable hr_formatter
    variable json_formatter

    constructor {} {
        set hr_formatter    [::ngis::HRFormat   create [::ngis::Formatters new_cmd hr]]
        set json_formatter  [::ngis::JsonFormat create [::ngis::Formatters new_cmd json]]

        # setting the default
        set formatter $hr_formatter
    }

    destructor { }

    method format {} {
        return [$formatter format]
    }

    method set_format {f} {
        switch -nocase $f {
            HR {
                set formatter $hr_formatter
            }
            JSON {
                set formatter $json_formatter
            }
            default {
                return -code 1 "Invalid formatter: must be either HR or JSON"
            }
        }
    }

    method current_formatter {} { return $formatter }

    method parse_exec_cmd {cmd_line} {
        set cmd_line [string trim $cmd_line]
        ::ngis::logger debug "msg >$cmd_line< ([string length $cmd_line])"
        if {[regexp -nocase {^(\w+)\s*.*$} $cmd_line m cmd] == 0} {
            return "101: unrecognized or invalid command '$cmd_line'"
        } else {
            
            # we require the protocol command to be strictly uppercase for
            # best reading of errors and log lines

            if {[regexp {^([A-Z]+)\s+(.*)$} $cmd_line m cmd arguments] == 0} {
                set arguments ""
            }

            if {[dict exists $::cs_protocol $cmd]} {
                set cmd_o [dict get $::cs_protocol $cmd]

                # we can't write the following line in compact form
                # as [eval $formatter [$cmd_o exec {*}$arguments]]
                # since method exec actually may change the format

                set proto_msg [$cmd_o exec {*}$arguments]
                return [eval $formatter $proto_msg]
            }

            ::ngis::logger debug "arguments: '$arguments' (nargs: [llength $arguments])"
            switch $cmd {
                NOOP {
                    return [$formatter c120]
                }
                STOP {
                    [$::ngis_server get_job_controller] stop_operations
                    ::ngis::logger emit "got a 'stop_operations' signal"
                    return [$formatter c502]
                }
                SHUTDWN {
                    $::ngis_server shutdown
                    return [$formatter c100]
                }
                default {
                    return [$formatter c101 "Unrecognized command $cmd"]
                }
            }
        }
    }
}

namespace eval ::ngis::Protocol {
    proc mkprotocol {} { return [::ngis::Protocol new] }
}

package provide ngis::protocol 2.0
