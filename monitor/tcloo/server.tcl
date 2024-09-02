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
package require ngis::clientmsg
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
        dict set connections_db $con connection_status [ngis::ClientMessages::mkretcodes]
    }

    method RemoveConnection {con} {
        if {[dict exists $connections_db $con]} {
            set retcodes [dict get $connections_db $con connection_status]
            $retcodes destroy
            dict unset connections_db $con
        }
    }

    method get_connection {con} {
        return [dict get $connections_db $con]
    }

    method get_connection_status {con} {
        return [dict get $connections_db $con connection_status]
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

    method cmd_parser {socketid args} {
        set return_codes [my get_connection_status $socketid]

        set msg [string trim $args]
        puts "msg >$msg ([llength $msg])<"
        if {[regexp -nocase {^(\w+)\s*.*$} $msg m cmd] == 0} {
            my send_to_client $socketid "000: unrecognized command '$msg'"
        } else {
            set arguments  [lrange $msg 1 end]
            set narguments [llength $arguments]
            #puts "arguments: '$arguments' ($narguments)"
            switch [string toupper $cmd] {
                CHECK {
                    if {$narguments < 1} {
                        my send_to_client $socketid [$return_codes compose 003 $arguments]
						break
                    }

                    if {[catch {
	                    set service_check [lindex $arguments 0]
						if {[string is integer $service_check]} {
							set service_d [::ngis::service load_by_gid $service_check]
							if {$service_d == ""} {
								my send_to_client $socketid [$return_codes compose 005 $service_check]
							} else {
                                if {[dict exists $service_d record_description]} {
                                    set description [dict get $service_d record_description]
                                } elseif {[dict exists $service_d record_entity]} {
                                    set description [dict get $service_d record_entity]
                                } else {
                                    set description "Unnamed record (gid=$service_check)"
                                }

								$job_controller post_sequence [::ngis::JobSequence create ::ngis::seq[incr nseq] \
									[::ngis::PlainJobList create ::ngis::ds[incr ds_nseq] [list $service_d]] $description]

								my send_to_client $socketid [$return_codes compose 002]
							}
						} else {
							set entity $service_check
                            set limit 0
							::ngis::logger emit "CHECK arguments $arguments"
                            if {$narguments == 2} { 
                                set limit [lindex $arguments 1] 
                                if {!([string is integer $limit] && ($limit > 0))} {
                                    my send_to_client $socketid [$return_codes compose 011]
                                    break
                                }
                            }
							set resultset [::ngis::service load_by_entity $entity -limit $limit -resultset]
                        
							$job_controller post_sequence [::ngis::JobSequence create ::ngis::seq[incr nseq] \
																	[::ngis::DBJobSequence create ::ngis::ds[incr ds_nseq] $resultset] $entity]
							my send_to_client $socketid [$return_codes compose 002]
						}
					} e einfo]} {
						my send_to_client $socketid [$return_codes compose 007 $e $einfo]
					}
                }
                STOP {
                    $job_controller stop_operations
                    my send_to_client $socketid [$return_codes compose 102]
                }
                QUERY {
                    if {$narguments == 0} {
						set jc_status [$job_controller status]
                        my send_to_client $socketid [$return_codes compose 106 {*}$jc_status]
                    } else {
						my send_to_client $socketid [$return_codes compose 009 "[string toupper $cmd] $arguments"]
					}
                }
                FORMAT {
                    if {$narguments == 0} {
                        my send_to_client $socketid [$return_codes compose 104 [$return_codes format]]
                    } elseif {$narguments == 1} {
                        set fmt [lindex $arguments 0]
                        switch -nocase $fmt {
                            RAW -
                            JSON -
                            HR {
                                $return_codes set_format [string toupper $fmt]
                                my send_to_client $socketid [$return_codes compose 104 [$return_codes format]]
                            }
                            default {
                                my send_to_client $socketid [$return_codes compose 001 $msg]
                            }
                        }
                    } else {
                        my send_to_client $socketid [$return_codes compose 003 $arguments]
                    }
                }
                SET {

                }
                EXIT {
                    $job_controller shutdown_server
                    my send_to_client $socketid [$return_codes compose 000]
                }
                default {
                    my send_to_client $socketid [$return_codes compose 001 $msg]
                }
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
            if {[catch { eval my cmd_parser $con $msg } e einfo]} {
                set return_codes [my get_connection_status $con]
                my send_to_client $con [$return_codes compose 501 $e $einfo]
            }

        } else {

            # this might happen when the client issues a chan close command
            # but no data were in the socket buffer

            ::ngis::logger emit "empty line on read, ignoring"
            catch {my send_to_client $con "empty line on read, ignoring"}
        }

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

        set tcp_channel [socket -server [namespace code [list my accept_tcp_connection]] 4422]
        ::ngis::logger emit "server listening on tcp socket '$tcp_channel'"

        # the job_controller_object has a global accessible and defined name

        set job_controller [::ngis::JobController create ::the_job_controller $max_workers]

        vwait ::wait_for_events

        ::ngis::logger emit "monitor server shuts down"

        chan close $listen
        chan close $tcp_channel
    }

}

package provide ngis::server 1.0
