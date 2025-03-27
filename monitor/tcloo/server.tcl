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
package require ngis::utils

::oo::class create ::ngis::Server 

#puts "Protocol: [package present ngis::protocol]"

::oo::define ::ngis::Server {
    variable connections_db [dict create]
    variable job_controller
    variable current_connection
    variable protocol
    variable nseq
    variable ds_nseq
    variable start_time

    # task results variables and structures
    variable task_results_chore
    variable task_results_queue

    constructor {} {
        set nseq    -1
        set ds_nseq -1
        set start_time [clock seconds]
        set current_connection ""
        set protocol [ngis::Protocol::mkprotocol]

        set task_results_chore      ""
        set task_results_queue      [::struct::queue ::ngis::task_results]
    }

    method RegisterConnection {con ctype} {
        ::ngis::logger emit "registering connection $con"
        dict set connections_db $con format   HR
        dict set connections_db $con login    [clock seconds]
        dict set connections_db $con type     $ctype
        dict set connections_db $con ncmds    0
        dict set connections_db $con last_cmd [clock seconds]
    }

    method UpdateConnection {con} {
        dict with connections_db $con { 
            incr ncmds 
        }
    }

    method UpdateConnectionTimestamp {con} {
        dict with connections_db $con { 
            set last_cmd [clock seconds]
        }
    }

    method RemoveConnection {con} {
        if {[dict exists $connections_db $con]} {
            dict unset connections_db $con
        }
    }

    method get_connection {con} {
        return [dict get $connections_db $con]
    }

    method get_connection_format {} {
        if {$current_connection != ""} {
            # ASSERT: the current_connection key
            # must be defined in the connections db
            return [dict get $connections_db $current_connection format]
        }
        return ""
    }

    method set_connection_format {fmt} {
        if {$current_connection != ""} {
            # ASSERT: the current_connection key
            # must be defined in the connections db
            # and fmt must be either HR or JSON
            dict set connections_db $current_connection format $fmt

            $protocol set_format $fmt
        }
    }

    method send_to_client {con msg} {
        try {
            chan puts $con $msg
            #chan puts $con $::ngis::end_of_answer
            chan flush $con
        } on error {e einfo} {
            ::ngis::logger emit "error responding to client ($e, $einfo)"
        }
    }

    method whos {} {
        set keys [lsort [dict keys $connections_db]]

        set whos_l [list]
        dict for {c con_d} $connections_db {
            dict with con_d {

                # returning a list with the following data
                #  + login datetime
                #  + connection tyle (either unix socket or tcp/ip
                #  + number of processed commands
                #  + connection of protocol messages
                #  + idle time

                set idle_time_s [::ngis::utils::delta_time_s [expr [clock seconds] - $last_cmd]]
                set datetime    [clock format $login -format "%d-%m-%Y %H:%M:%S"]
                lappend whos_l [list $datetime $type $ncmds $format $idle_time_s]
            }
        }
        return $whos_l
    }

    # -- task results procedures

    method post_task_results {task_results} {
        $task_results_queue put $task_results
        if {([$task_results_queue size] >= $::ngis::task_results_queue_size) && \
            ($task_results_chore == "")} {
            set task_results_chore [after 100 [list [self] sync_results]]
        }
    }

    method post_task_results_cleanup {gid tasks_to_purge_l} {
        after 100 [[self] remove_results $gid $tasks_to_purge_l]
    }

    method sync_results {} {
        set task_results_chore ""
        set results_queue   $task_results_queue

        if {[$results_queue size] == 0} { return }

        # hideous behavior of struct::queue: if it's
        # holding one element that can be represented as a list, 
        # subcommand 'get' returns a flat list of elements,
        # not a 1 element list.  It's documented, but nonetheless
        # a despicable way Tcllib's struct::queue works

        if {[$results_queue size] == 1} {
            set results_l [list [$results_queue get]]
        } else {
            set results_l [$results_queue get [$results_queue size]]
        }

        if {[catch {
            ::ngis::logger emit "storing [llength $results_l] results"
            set t1 [clock milliseconds]
            ::ngis::service::update_task_results $results_l
            set t2 [clock milliseconds]

            ::ngis::logger emit "[llength $results_l] results stored in [expr $t2 - $t1]ms"
        } e einfo]} {
            ::ngis::logger emit "error syncing results: $e"
            ::ngis::logger emit "===== error_info ====="
            foreach l [split $einfo "\n"] { ::ngis::logger emit $l }
        }
    }

    method remove_results {gid tasks_to_purge_l} {
        ::ngis::logger emit "removing [llength $tasks_to_purge_l] results for gid '$gid'"
        ::ngis::service remove_task_results $gid $tasks_to_purge_l
    }


    # chan_is_readable --
    #
    # socket I/O callback. The Tcl channel reference 'con' is the key to access
    # the database of connections and protocol setting. This procedure and
    # subsequent command elaboration (method parse_exec_cmd) is synchronous,
    # so we can assume that current_connection is not going to change during a
    # message elaboration. This simplification comes at the cost of blocking
    # the event loop and therefore we need to pay close attention to delays
    # and in perspective redesign the I/O handling devolving its tasks to threads

    method chan_is_readable {con} {
        set current_connection $con
        if {[chan eof $con]} {

            ::ngis::logger emit "eof detected on channel $con"
            chan close $con
            my RemoveConnection $con
            return

        } else {

            if {[catch {gets $con msg} e einfo]} {

                ::ngis::logger emit "error detected on 'gets <channel>': $e"
                chan close $con
                my RemoveConnection $con

            } elseif {$e > 0} {

                my UpdateConnection $con
                my UpdateConnectionTimestamp $con

                ::ngis::logger emit "Got $e chars in message \"$msg\" from $con"

                my set_connection_format [dict get $connections_db $con format]

                #puts "read from socket: >$msg<"

                if {[catch { set ret2client [$protocol parse_exec_cmd $msg] } e einfo]} {
                    ::ngis::logger emit "error: $e"
                    ::ngis::logger emit "einfo: $einfo"

                    my send_to_client $con [[$protocol current_formatter] c501 $e]
                } else {
                    my send_to_client $con $ret2client
                }

            } else {

                # this might happen when the client issues
                # a chan close command but no data were in
                # the socket buffer

                ::ngis::logger emit "empty line on read, ignoring"
            }
        }

        set current_connection ""
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
        set socket_dir [file dirname $::ngis::unix_socket_name]
        if {[file exists $socket_dir] == 0} {
            file mkdir $socket_dir
        }

        set listen [unix_sockets::listen $::ngis::unix_socket_name [namespace code [list my accept]]]
        ::ngis::logger emit "server listening on socket '$listen'"

        if {$::ngis::tcpaddr != ""} {
            set tcp_channel [socket -myaddr $::ngis::tcpaddr \
                                    -server [namespace code [list my accept_tcp_connection]] $::ngis::tcpport]
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
