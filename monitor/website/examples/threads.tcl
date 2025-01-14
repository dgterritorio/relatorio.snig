    package require Thread

    set thread_id [::thread::create -joinable -preserved {
        lappend auto_path "."
        package require ngis::ancillary_io_thread

        socket_connect

        ::thread::wait

        if {$connection != ""} { chan close $connection }
    }]
