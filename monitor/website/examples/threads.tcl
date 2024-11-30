    set thread_id [::thread::create -joinable -preserved {
        lappend auto_path ".."
        package require ngis::conf
        package require json
        package require syslog

        set tasks_l ""

        proc log_msg {s} {
            syslog -perror -ident snig -facility user info $s
        }

        proc get_data {} {
            global tasks_l

            return $tasks_l
        }

        proc data_ready {} {
            global tasks_l

            if {$tasks_l != ""} { 
                #puts ""
                return true 
            }
            return false
        }

        proc read_data {con} {
            set answer ""
            while {![chan eof $con] && [chan gets $con l] > 0} { 
                #puts $l
                append answer $l
            }
            return $answer
        }

        proc fetch_registered_tasks {} {
            global tasks_l

            set tasks_l ""
            set con [socket $::ngis::tcpaddr $::ngis::tcpport]
            chan puts  $con "FORMAT JSON"
            chan flush $con
            set answer [read_data $con]
            set answer_d [::json::json2dict $answer]
            if {[dict exists $answer_d code]} {
                dict with answer_d {
                    log_msg "Server returned code $code ($message)"
                }
            }

            chan puts  $con "REGTASKS"
            chan flush $con

            set answer [read_data $con]
            set answer_d [::json::json2dict $answer]
            set tasks_dl [dict get $answer_d tasks]
            set tl [lmap t $tasks_dl {
                dict with t {
                    set task_v [list $task $function $description $procedure $script]
                }
                set task_v
            }]
            set tasks_l $tl
            chan close $con
            log_msg "Server returned $tasks_l"
            return $tasks_l
        }

        ::thread::wait
    }]
