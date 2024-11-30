set n 0
::thread::send $::ngis::ancillary_thread [list send_command "FORMAT JSON"]
set status ""
while {($status != "data_ready") && [incr n]} {
    ::thread::send $::ngis::ancillary_thread [list get_status] status
    after 100
    if {$n > 10} {
        ::rivet::apache_log_error err "ancillary thread timeout"
        break
    }
}
::thread::send $::ngis::ancillary_thread [list get_data] json_data
#::rivet::apache_log_error err "server responded with code [dict get $json_data code]"

::thread::send $::ngis::ancillary_thread [list send_command "REGTASKS"]
set status ""
set n 0
while {($status != "data_ready") && [incr n]} {
    ::thread::send $::ngis::ancillary_thread [list get_status] status
    after 100
    if {$n > 10} {
        ::rivet::apache_log_error err "ancillary thread timeout"
        break
    }
}
::thread::send $::ngis::ancillary_thread [list get_data] json_data
#::rivet::apache_log_error err "server responded with code [dict get $json_data code]"

puts $json_data

