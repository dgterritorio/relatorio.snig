#
# -- server.tcl
#
#
#
#

package require TclOO
package require Thread
package require unix_sockets
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

    method register_connection {con} {
        puts "registering connection $con"
        dict set connections_db $con protocol [ngis::Protocol::mkprotocol]
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
        chan puts $con $::ngis::end_of_answer
        chan flush $con
    }

    method sync_results {result_queue} {
        if {[$result_queue size] == 0} { return }
        ::ngis::logger emit "syncing [$result_queue size] results"
        
        while {[$result_queue size] > 0} {
            ::ngis::service::update_task_results [$result_queue get]
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
                my send_to_client $con [$protocol compose 501 $e $einfo]
            } else {
                my send_to_client $con $ret2client
            }

        } else {

            # this might happen when the client issues a chan close command
            # but no data were in the socket buffer

            ::ngis::logger emit "empty line on read, ignoring"
            catch {my send_to_client $con "empty line on read, ignoring"}
        }
    }

    method get_job_controller {} { return $job_controller }

    method shutdown {} {
        $job_controller server_shutdown
        incr ::wait_for_events
    }

    method accept {con} {
        my register_connection $con
        ::ngis::logger emit "Accepting connection on $con"
        chan event $con readable [namespace code [list my chan_is_readable $con]]
    }

    method accept_tcp_connection {con clientaddr clientport} {
        my register_connection $con
        ::ngis::logger emit "Accepting tcp connection from $clientaddr ($clientport)"
        chan event $con readable [namespace code [list my chan_is_readable $con]]
    }

    method run {max_workers} {
        set listen [unix_sockets::listen $::ngis::unix_socket_name [namespace code [list my accept]]]
        ::ngis::logger emit "server listening on socket '$listen'"

        if {$::ngis::tcpaddr != ""} {
            set tcp_channel [socket -myaddr $::ngis::tcpaddr -server [namespace code [list my accept_tcp_connection]] 4422]
            ::ngis::logger emit "server listening on tcp socket '$tcp_channel'"
        }
        # the job_controller_object has a global accessible and defined name

        set job_controller [::ngis::JobController create ::the_job_controller $max_workers]

        vwait ::wait_for_events

        ::ngis::logger emit "monitor server shuts down"

        chan close $listen
        if {[info exists tcl_channel]} { chan close $tcp_channel }
    }

}

package provide ngis::server 1.0
