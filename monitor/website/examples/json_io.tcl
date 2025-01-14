lappend auto_path ".."
package require ngis::conf
package require json
package require syslog

set tasks_l ""
set connection ""
set connection_status idle
set data_buffer ""
set json_data ""


# ChatGPT provided procedure

proc isValidJSON {inputString parsed_data_v} {
    upvar 1 $parsed_data_v parsed_json

    # Try to parse the JSON string
    #puts "validating ->> $inputString"

    if {[catch {
        set parsed_json [::json::json2dict $inputString]
        set retvalue 1
    } e einfo]} {
        #puts [string repeat "---" 20]
        #puts $e
        #puts [string repeat "---" 20]
        return 0
    }

    return $retvalue
}

# Example usage
#set testString1 "{\"key\": \"value\", \"number\": 123}"
#set testString2 "{invalid JSON}"

#puts "Test 1: [isValidJSON $testString1]"  ;# Output: 1 (valid JSON)
#puts "Test 2: [isValidJSON $testString2]"  ;# Output: 0 (invalid JSON)

proc log_msg {s} {
    syslog -perror -ident snig -facility user info $s
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

proc get_status {} {
    global connection_status

    return $connection_status
}

proc set_status {new_status} {
    global connection_status

    set connection_status $new_status
}

proc get_data {} {
    global json_data

    set_status idle
    return $json_data
}


proc read_from_chan {con} {
    global data_buffer
    global json_data

    if {[chan eof $con]} {
        set_status eof
    }

    set cstatus [get_status]
    if {$cstatus != "wait" && $cstatus != "reading"} {
        chan gets $con l
        #puts "unexpected data '$l' with status: $cstatus"
        return
    }

    set_status reading

    chan gets $con l

    append data_buffer $l
    #puts "..> $data_buffer"

    if {[isValidJSON $data_buffer parsed_data]} {
        #puts "JSON data ready"

        set_status data_ready
        set json_data $parsed_data
        incr ::counter
    }
}

proc send_command {cmd} {
    global data_buffer
    global connection

    set data_buffer ""
    chan puts $connection $cmd
    chan flush $connection
    set_status wait
}

proc exit_thread {} {
    ::thread::release
}

set connection [socket $::ngis::tcpaddr $::ngis::tcpport]
chan event $connection readable [list read_from_chan $connection]

send_command "FORMAT JSON"
puts "\n--------\nstatus: [get_status]"

vwait ::counter

#send_command "REGTASKS"
#vwait ::counter

#puts [get_data]
