lappend auto_path .

package require TclOO
package require ngis::conf
package require unix_sockets
package require tclreadline

::oo::class create ::ngis::Client {
	variable cmdcount
    variable pending_exit
	variable scheduled_input

    constructor {} {
        set cmdcount        0
        set pending_exit    false
        set scheduled_input ""
    }
    
    method parse_cmd_line {cmdline cmd_args_v} {
        upvar 1 $cmd_args_v cmd_args

        set cmd [lindex $cmdline 0]
        set cmd_args [lrange $cmdline 1 end]

        switch -nocase $cmd {
            P -
            C -
            F -
            SX -
            LT -
            LE -
            T -
            S -
            Q - 
            X {
                return $cmd
            }
            default {
                puts "Unknown Command '$cmd'"
            }
        }
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

    method send_to_server {chanid args} {
        chan puts $chanid [join $args]
        chan flush $chanid
    }

    method stop_client {} {
        incr ::client_event_loop_variable
    }

    method terminal_input {con} {
        set scheduled_input ""
		set line ""
		incr cmdcount
		while {$line == ""} {
			set line [::tclreadline::readline read "ngis\[$cmdcount\]> "]
        }
        set parsed_cmd [my parse_cmd_line $line cmd_args]
        switch -nocase $parsed_cmd {
            P {
                my send_to_server $con PENDING
            }
            LT {
                my send_to_server $con REGTASKS
            }
            LE {
                my send_to_server $con [concat ENTITIES $cmd_args]
            }
            C {
                if {[llength $cmd_args] > 0} {
                    #set service_id [lindex $cmd_args 0]
                    my send_to_server $con [list CHECK {*}$cmd_args]
                } else {
                    puts "missing command argument"
                    after 10 [namespace code [list my terminal_input $con]]
                }
            }
            F {
                my send_to_server $con [concat FORMAT $cmd_args]
            }
            Q {
                my send_to_server $con [concat QUERY $cmd_args]
            }
            S {
                my send_to_server $con START
            }
            T {
                my send_to_server $con STOP
                if {([llength $cmd_args] > 0) && ([lindex $cmd_args 0] == "-wait")} {
                    after 1000
                    my send_to_server $con QUERY
                }
            }
            SX {
                set pending_exit true
                my send_to_server $con EXIT
            }
            X {
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
