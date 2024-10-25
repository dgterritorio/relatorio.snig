#
# -- server.tcl
#
#
#
#

package require TclOO
package require Thread
package require unix_sockets
package require struct::queue
package require ngis::msglogger
package require json
package require ngis::protocol
package require ngis::conf
package require ngis::jobcontroller
package require ngis::servicedb
package require ngis::sequence

::oo::class create ::ngis::Server 

::oo::define ::ngis::Server {
    variable connections_db [dict create]
    variable job_controller
    variable nseq
    variable ds_nseq

    constructor {} {
        set nseq    -1
        set ds_nseq -1
    }

    method RegisterConnection {con ctype} {
        puts "registering connection $con"
        dict set connections_db $con protocol [ngis::Protocol::mkprotocol]
        dict set connections_db $con login    [clock seconds]
        dict set connections_db $con type     $ctype
        dict set connections_db $con ncmds    0
    }

    method UpdateConnection {con} {
        dict with connections_db $con { incr ncmds }
    }

    method RemoveConnection {con} {
        if {[dict exists $connections_db $con]} {
            set retcodes [dict get $connections_db $con protocol]
            $retcodes destroy
            dict unset connections_db $con
        }
    }

    method get_connection {con} {
        return [dict get $connections_db $con]
    }

    method get_protocol {con} {
        return [dict get $connections_db $con protocol]
    }

    method send_to_client {con msg} {
        chan puts $con $msg
        #chan puts $con $::ngis::end_of_answer
        chan flush $con
    }

    method whos {} {
        set keys [lsort [dict keys $connections_db]]

        set whos_l [list]
        dict for {c con_d} $connections_db {
            dict with con_d {
                lappend whos_l [list [clock format $login] $type $ncmds [$protocol format]]
            }
        }
        return $whos_l
    }

    method sync_results {result_queue} {
        if {[$result_queue size] == 0} { return }
        ::ngis::logger emit "syncing [$result_queue size] results"
        if {[$result_queue size] > 0} {

            # hideous behavior of struct::queue. If it's returning
            # one element, but it's a list, it becomes a list of elements
            # It's documented, but still a despicable way Tcl works

            if {[$result_queue size] == 1} {
                set results_l [list [$result_queue get]]
            } else {
                set results_l [$result_queue get [$result_queue size]]
            }

            if {[catch {
                ::ngis::service::update_task_results $results_l
            } e einfo]} {
                ::ngis::logger emit "error syncing results: $e"
                ::ngis::logger emit "===== error_info ====="
                foreach l [split $einfo "\n"] { ::ngis::logger emit $l }
            }
        }
    }

    method chan_is_readable {con} {
        if {[chan eof $con]} {

            ::ngis::logger emit "eof detected on channel $con"
            chan close $con
            my RemoveConnection $con
            return

        }

        if {[catch {gets $con msg} e einfo]} {

            ::ngis::logger emit "error detected on 'gets <channel>': $e"
            chan close $con
            my RemoveConnection $con

        } elseif {$e > 0}  {

            ::ngis::logger emit "Got $e chars in message \"$msg\" from $con"
            #eval my cmd_parser $con $msg

            set protocol [my get_protocol $con]

            if {[catch { set ret2client [$protocol parse_cmd {*}$msg] } e einfo]} {
                puts "e: $e"
                puts "einfo: $einfo"

                ::ngis::logger emit $e
                my send_to_client $con [$protocol compose 501 $e $einfo]
            } else {
                my send_to_client $con $ret2client
            }
            my UpdateConnection $con

        } else {

            # this might happen when the client issues a chan close command
            # but no data were in the socket buffer

            ::ngis::logger emit "empty line on read, ignoring"
            #catch {my send_to_client $con "empty line on read, ignoring"}
        }
    }

    method get_job_controller {} { return $job_controller }

    method shutdown {} {
        $job_controller server_shutdown
        incr ::wait_for_events
    }

    method accept {con} {
        my RegisterConnection $con "unix-socket"
        ::ngis::logger emit "Accepting connection on $con"
        chan event $con readable [namespace code [list my chan_is_readable $con]]
    }

    method accept_tcp_connection {con clientaddr clientport} {
        my RegisterConnection $con "TCP/IP"
        ::ngis::logger emit "Accepting TCP connection from $clientaddr ($clientport)"
        chan event $con readable [namespace code [list my chan_is_readable $con]]
    }

    method create_job_controller {max_workers} {
        set job_controller [::ngis::JobController create ::the_job_controller $max_workers]
    }

    method run {max_workers} {
        set listen [unix_sockets::listen $::ngis::unix_socket_name [namespace code [list my accept]]]
        ::ngis::logger emit "server listening on socket '$listen'"

        if {$::ngis::tcpaddr != ""} {
            set tcp_channel [socket -myaddr $::ngis::tcpaddr -server [namespace code [list my accept_tcp_connection]] 4422]
            ::ngis::logger emit "server listening on tcp socket '$tcp_channel'"
        }
        # the job_controller_object has a global accessible and defined name

        set job_controller [my create_job_controller $max_workers]

        vwait ::wait_for_events

        ::ngis::logger emit "monitor server shuts down"

        chan close $listen
        if {[info exists tcl_channel]} { chan close $tcp_channel }
    }

}

package provide ngis::server 1.0
