#!/usr/bin/tclsh

package require Thread

set thread_id [::thread::create -joinable {
    lappend auto_path "."
    package require ngis::conf
    package require json
    package require syslog

    set answer_d   ""

    proc read_data {} {
        global answer_d

        return $answer_d
    }

    proc data_ready {} {
        global answer_d

        puts -nonewline "."
        flush stdout
        if {$answer_d != ""} { 
            puts ""
            return true 
        }
        return false
    }

    proc read_data {con} {
        set answer ""
        while {![chan eof $con] && [chan gets $con l] > 0} { 
            puts $l
            append answer $l
        }
        return $answer
    }

    proc log_msg {s} {
        syslog -perror -ident snig -facility user info $s
    }

    proc fetch_data {} {
        global answer_d

        set answer_d ""
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
        set tasks_l [dict get $answer_d tasks]

        chan close $con
        return $answer_d
    }

    ::thread::wait
}]

thread::send -async $thread_id fetch_data
puts "sent data request"

set is_ready false
while {!$is_ready} {
    after 1000
    thread::send $thread_id data_ready is_ready
}

thread::send $thread_id read_data parsed_json_data
thread::release $thread_id

thread::join $thread_id


