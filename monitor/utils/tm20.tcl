source [file normalize [file join [file dirname [info script]] ".." tcloo thread_master.tcl]]

set tm [::ngis::ThreadMaster create ::threadm 50]
set threadid [$tm start_worker_thread ]

