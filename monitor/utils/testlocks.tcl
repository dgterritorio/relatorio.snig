#!/usr/bin/tclsh

package require Thread

::tsv::set protected threadid ""
::tsv::set protected nthreads 0

set thread_list {}
set nthreads 40

for {set n 1} {$n <= $nthreads} {incr n} {

    set threadid [thread::create -joinable {
        variable tn

        proc settn {n} {
            variable tn
            set tn $n
        }

        proc emit {m} {
            variable tn
            puts "\[$tn\] $m" 
            flush stdout
        }

        proc lock_and_write {} {
            variable tn
            tsv::incr protected nthreads
            set thread_count [tsv::get protected nthreads]
            emit "start lock_and_write"
            set n 0
            while {[incr n] <= 2} {
                emit "attempt to lock 'protected' ($n)"
                tsv::lock protected {
                    emit "got lock on 'protected' ($n)"
                    tsv::set protected threadid [thread::id]
                    after 500
                    tsv::set protected threadid ""
                    tsv::set protected last_thread $tn


                }
                emit "release lock on 'protected' ($n)"
                after $thread_count
            }
            emit "[expr $n-1] loops completed"
            tsv::incr protected nthreads -1
        }

        proc exit_thread {} {
            emit "thread being released"
            thread::release
        }

        thread::wait
    }]

    lappend thread_list $threadid

    ::thread::preserve $threadid
    thread::send $threadid [list settn $n]
}

set threader [thread::create -joinable {
    variable tn 0

    proc emit {m} {
        variable tn
        puts "\[$tn\] $m" 
        flush stdout
    }

    proc read_unlocked {} {
        emit "start read_unlocked"
        set n 0
        while {[tsv::get protected nthreads] == 0} { after 100 }
        while {[incr n] < 1000} {
            set thread_count [tsv::get protected nthreads]
            if {$thread_count == 0} {
                emit "Reader terminates after $n loops"
                return 
            }
            set ts [clock milliseconds]
            set running_threads [tsv::get protected nthreads]
            emit "attempt to read unlocked (competing with $running_threads threads) ($n)"
            set threadid [tsv::get protected threadid]
            set last_thr [tsv::get protected last_thread]
            emit "waited [expr [clock milliseconds]-$ts]"
            if {$threadid != ""} {
                emit "#### accessing protected variable ($n)"
            }
            emit "last_thread registered locking thread: $last_thr ($n)"

            if {$thread_count > 2} {
                after 1
            } else {
                after 5
            }
        }
    }

    proc exit_thread {} {
        thread::release
    }

    puts "\[[thread::id]\] loaded"
    thread::wait
}]

puts "[llength $thread_list] threads created"

puts "sending tasks to [llength $thread_list]..."
thread::send -async $threader read_unlocked
foreach threadid $thread_list { thread::send -async $threadid lock_and_write }
puts "tasks sent..."

while {[tsv::get protected nthreads] > 0} { 
    puts "[tsv::get protected nthreads] threads still running"
    after 1000
}
foreach ti $thread_list {
	thread::send -async $ti exit_thread
}

foreach id $thread_list {
    puts -nonewline "joining thread $id..."
    thread::join $id
    puts "done"
}

thread::send -async $threader exit_thread
puts -nonewline "joining thread $threader..."
thread::join $threader
puts "done"

puts [::tsv::get protected nthreads]
