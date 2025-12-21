# client.tcl --
#
#
#

package require TclOO
package require ngis::conf
package require ngis::common
package require unix_sockets
package require tclreadline

::oo::class create ::ngis::Client {
	variable cmdcount
	variable scheduled_input

    constructor {} {
        set cmdcount        0
        set scheduled_input ""
    }
    
    method process_server_message {con msg} {
        if {$scheduled_input != ""} {
            after cancel $scheduled_input
        }
        set scheduled_input [after 500 [namespace code [list my terminal_input $con]]]
        puts "$msg"
    }

    # actual asynchronous data reader.
    # The procedure checks for the eof condition
    # and in case closes the channel associated with
    # the socket

    method socket_readable {con} {

        if {[chan eof $con]} {
            puts "eof detected"
            chan close $con
            my stop_client
            return
        }

        set server_msg [chan gets $con]
        my process_server_message $con $server_msg

    }

    method send_to_server {chanid server_cmd} {
        chan puts  $chanid $server_cmd
        chan flush $chanid
    }

    method stop_client {} {
        incr ::client_event_loop_variable
    }

    method terminal_input {con} {
        set cli $::ngis::cli::cli
        set scheduled_input ""
		set line ""
		incr cmdcount
		while {$line == ""} {
			set line [::tclreadline::readline read "snig \[$cmdcount\]> "]
        }
        set cli_result [$cli dispatch $line]
        lassign $cli_result cli_result cli_cmd cli_args

        #puts "a1: $a1, a2: $a2, a3: $a3"

        switch $cli_result {
            OK {
                my send_to_server $con [list $cli_cmd {*}$cli_args]
            }
            ERR {
                set cmd_args [string trim "$cli_cmd $cli_args"]
                puts "Error: $cli_result ($cmd_args)"
                set scheduled_input [after 10 [namespace code [list my terminal_input $con]]]
            }
            EXIT {
                my stop_client
            }
            default {
                set scheduled_input [after 10 [namespace code [list my terminal_input $con]]]
            }
        }
    }

    method open_channel {} {
        set con [unix_sockets::connect $::ngis::unix_socket_name]
        chan event $con readable [namespace code [list my socket_readable $con]]
        return $con
    }

    method run {args} {

        if {[info exists ::env(HOME)]} {
            set homedir $::env(HOME)
        } else {
            set homedir "."
        }

        set client_history [file join $homedir .ngishistory]

        puts "history file: $client_history"

        ::tclreadline::readline initialize $client_history

        if {[llength $args] == 2} {
            lassign $args tcpaddr tcpport
            set con [socket $tcpaddr $tcpport]
            chan event $con readable [namespace code [list my socket_readable $con]]
        } else {
            set con [my open_channel]
        }
        after 10 [namespace code [list my terminal_input $con]]

        vwait ::client_event_loop_variable

        ::tclreadline::readline write $client_history
        puts "client exits"
    }
}

package provide ngis::client 1.0
