#
# -- safelock.tcl
#

namespace eval ::safelock {
    variable safelock_cnt   0
    variable lock_map
    array set lock_map  {}

# -- log_message
#
# funzione generica di logging. Se lo script gira sotto mod_rivet
# allora il messaggio viene inviato alla log facility di Apache
# altrimenti viene stampato su stderr dopo aver fatto il prepend
# del testo con la severity specificata.

    proc log_message {msg {severity "info"}} {

        if {[catch {::rivet::apache_log_error $severity $msg} e]} {
            puts stderr "\[$severity\] $msg"
        }

    }
    namespace export log_message

# -- make_fake_session
#
# negli script di test la sessione generata da mod_rivet (Session)
# non è definita. Questa procedura nel crea una
#

    proc make_fake_session {} {
        set sessione "[pid][clock format [clock seconds] -format "%Y%m%d%H%M%S"]"
    }

# -- prepare_safelock
#
#
    proc prepare_safelock {} {
        variable lock_map
        variable safelock_cnt

        set safelock_cnt 0
        array unset lock_map
    }

# -- runsafelock
#
# procedura che lancia procedure con lock in atto. Qualunque
# sia l'esito della procedura viene garantito l'unlock
# delle tabelle bloccate.
#
# Argomenti:
#   - dbhandle: handle al database
#   - tables2lock: lista di elementi fatti 
#       * da coppie 'tabella tipo-di-lock' oppure 
#       * da solo dal nome della tabella
#   - tclcmd: struttura della procedura+argomenti da invocare
#
# Returned value:
#
#   viene restituito il valore ritornato dalla procedura
#   oppure, nel caso la sua esecuzione sia fallita, viene
#   ritornato lo stesso errore
#

    proc runsafelock {dbhandle tables2lock tclcmd} {
        variable safelock_cnt
        variable lock_map

        foreach tb $tables2lock {
            set table_lock [split $tb ":"]
            lassign $table_lock table locktype
            switch $locktype {
                r {
                    set locktype READ
                }
                default {
                    set locktype WRITE
                }
            }
            set lock_map($table) $locktype
        }

        set lock_tables ""
        foreach {tbl lck} [array get lock_map] {
            lappend lock_tables [list $tbl $lck]
        }

        #puts "running with lock [array get lock_map]"
        set sql "LOCK TABLES [join $lock_tables ,];"
        
        if {[catch { set sqlres [$dbhandle exec $sql] } ecode einfo]} {

            log_message "error locking database '$sql'"
            log_message "Error info: $einfo"
            return -options $einfo $ecode
               
        } else {

            $sqlres destroy

        }
        #log_message [list $safelock_cnt $sql $tclcmd]

        incr safelock_cnt

        set reterror [catch { set procv [uplevel 1 $tclcmd] } ecode eoptions]

        if {$safelock_cnt > 0} { incr safelock_cnt -1 }
        if {$safelock_cnt <= 0} {
            set sql "UNLOCK TABLES"
            set sqlres [$dbhandle exec $sql]
            $sqlres destroy
            log_message [list cnt $safelock_cnt $sql]
        }

        if {$reterror} {
            return -options $eoptions $ecode
        } else {
            return $procv
        }

    } 
    namespace export runsafelock

# -- assert_safelock
#
# controlla che il chimante sia controllato
# direttamente da runsafelock
#

    proc assert_safelock {lock_map} {
        variable safelock_cnt

        if {$safelock_cnt == 0} {
            return  -error unsafe_proc_call -code error \
                    -errorinfo "Chiamata a procedura senza safe lock"\
                               "Chiamata a procedura senza safe lock"
        }   

        #puts " [info level]: [info level [expr [info level] - 2]]"
        #lassign [info level [expr [info level]]] procedure
        #puts "controlling procedure '$procedure'"
        #if {$procedure != "::dbrete::utils::runsafelock"} {
        #    return  -error unsafe_proc_call -code error \
        #            -errorinfo "Chiamata a procedura senza safe lock"\
        #                       "Chiamata a procedura senza safe lock"
        #
        #}

        verify_lock $lock_map

        return -code ok
    }
    namespace export assert safelock

# -- verify_lock
#
# controlla che la lista dei lock sia quella
# richiesta dalla procedura chiamante
#

    proc verify_lock {lock_list} {
        variable lock_map

        # verifichiamo anche la lista dei lock
        #puts "lock_list $lock_list, lock_map: [array get lock_map]"

        foreach tb $lock_list {

            set table_lock [split $tb ":"]
            lassign $table_lock table locktype
            switch $locktype {
                r {
                    set locktype READ
                }
                default {
                    set locktype WRITE
                }
            }

            #puts "table $table, $locktype"
            if {[info exists lock_map($table)] && \
                ($lock_map($table) == $locktype)} {
                continue
            } else {

                set errmsg "Invalid or incomplete lock in procedure call"
                return -error       wrong_lock_on_proc_call \
                       -code        error \
                       -options     [dict create {*}[array get lock_map]] \
                       -errorinfo   $errmsg $errmsg
            }

        }
        return -code ok
    }
    namespace export verify_lock

# -- error
#
# funzione standard per generare condizioni di errore
# La funzione per ora ammette un terzo argomento come
# lista variabile di argomenti per permettere future
# espansioni a dizionari di condizioni di errore

    proc error {errcode errinfo args} {
        return -code error -errorcode $errcode -errorinfo $errinfo $errinfo
    }
    namespace export error

    namespace ensemble create
}

package provide safelock 1.0
