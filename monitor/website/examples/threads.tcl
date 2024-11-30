    package require Thread

    set thread_id [::thread::create -joinable -preserved {
        lappend auto_path "."
        package require ngis::ancillary_io_thread

        set connection [socket $::ngis::tcpaddr $::ngis::tcpport]
        chan event $connection readable [list read_from_chan $connection]

        ::thread::wait

        chan close $connection
    }]
