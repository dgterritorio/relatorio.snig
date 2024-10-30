## SNIG Services Monitor Internals

### Server Structural Diagram

```

            | Web Server |
                  .
                  .
           +-------------+
           |    TCP/IP   |
           |  connection |
           +-------------+
                  .        +--------------+
                  .        |  Unix Socket |  <... | Daily Job Client |
                  .        |  Connection  |  <... | CLI Client |
                  .        +--------------+
                  .               .
                  .               .
    +-----------------------------------------+
    |                                         |       +----------------+
    |     ::ngis::Server (Event Queue.        | <---- | Thread Manager |
    | Network, Threads and Jobs callbacks)    |       +----------------+
    |                                         |
    +-----------------------------------------+
                        |
                        |
    +-----------------------------------------+
    |         ::ngis::JobController           |
    +-----------------------------------------+
         ^      ^          ^
         |      |          |
         |      |    +-----------+   +------+   +------+       +------+
         |      |    |    Job    |-->| Job1 |-->| Job2 |....-->| Jobn |
         |      |    |  Sequence |   +------+   +------+       +------+
         |      |    +-----------+
         |      |    +-----------+   +------+   +------+       +------+
         |      +--->|    Job    |-->| Job1 |-->| Job2 |....-->| Jobn |
         |           |  Sequence |   +------+   +------+       +------+
         |           +-----------+
         |                 .
         |                 .
         |                 .
         |           +-----------+   +------+   +------+       +------+
         +---------->|    Job    |-->| Job1 |-->| Job2 |....-->| Jobn |
                     |  Sequence |   +------+   +------+       +------+
                     +-----------+
```
### Monitor Server Application Structure.

The Monitor Server is an asynchronous standalone application that uses
an event loop (controlled within the class `::ngis::Server`) to synchronize
and perform most operations.

Thus the server works essentially in response to events that may be either
socket connections event (TCP/IP or Unix Socket) or server
internal events, such as single task termination, job termination, 
job sequence termination and batched requests to store results.
Event callbacks are implemented by class object methods that have
been kept as simple as possibile in order to preserve the overall
server responsiveness to any events and offer them time slices.
Some callbacks performing relatively more complex operations
where designed to fit into the asynchronous model in order to
avoid delays and even momentary lock-ups. 

For example the `JobController::sequence_roundrobin` method, 
which implements a round-robin mechanism attempting to evenly
distribute available worker threads among *Job Sequences* 
(a *Job Sequence* is an ordered collection of *Jobs*), 
instead of looping over the whole pool of idle threads, it assigns a
thread to the next job sequence, as determined by the
round-robin alghoritm, and then resubmits itself for execution after a
configured time (default 100ms) to process the next idle thread.

The server maintains a pool of worker threads (see class
`::ngis::ThreadMaster`) to which specific tasks are devolved.
Threads were needed for the tasks execution since tasks are carried out
by a collection of scripts that leverage specialized external tools.
Such tools can be CLI program utilities with indefinite execution times
and thus don't fit into the asynchronous architecture of the application.
Having them running within separate threads allows the server to
continue to serve ordinary event posted on the event queue.

A thread manager (class `::ngis::ThreadManager`) spawns new tasks when 
requested (up to a maximum number of threads set in the configuration 
file `ngis_monitor_conf.tcl`) and makes them available to the job 
controller which in turn passes references of idle threads to the 
round-robin Job Sequences

### Job Execution and the Server Thread Pool

A *Job* is a set of tasks to be carried out for a specific service. The current
registered task list is show in this table.
```
+--------------------------------------------------------------------------------------------------------+
|                                         [110] Registered Tasks                                         |
+------------------+-----------+------------------------------+-------------------------------+----------+
| Task             | Procedure | Description                  | Script                        | Language |
+------------------+-----------+------------------------------+-------------------------------+----------+
| congruence       | run_tcl   | Record Data Congruence Check | 00_congruence.tcl             | Tcl      |
| url_status_codes | run_bash  | Check URL Status Codes       | 01_check_urls_status_codes.sh | Bash     |
| wfs_capabilities | run_bash  | WFS Capabilities             | 10_wfs_urls_capabilities.sh   | Bash     |
| wfs_ogr_info     | run_bash  | WFS OGRinfo Capabilities     | 20_wfs_url_ogrinfo.sh         | Bash     |
| wms_capabilities | run_bash  | WMS Capabilities             | 30_wms_urls_capabilities.sh   | Bash     |
| wms_gdal_info    | run_bash  | WMS GDAL info Capabilities   | 40_wms_url_gdalinfo.sh        | Bash     |
+------------------+-----------+------------------------------+-------------------------------+----------+
| [110] 7 registered tasks                                                                               |
+--------------------------------------------------------------------------------------------------------+
```
This table is the output of command `LT` of the command line interface.

When a thread is assigned to a Job method ::ngis::Job::post_task pulls the first available task from a 
queue and send it to the thread by calling procedure `do_task` in the recipient thread context 
```
method post_task {thread_id} {
        if {[catch { set task_d [$tasks_q get] } e einfo]} {

            # the queue is empty, tasks are completed and
            # the job sequence this job belongs to is notified
            # that we are done with our tasks

            my notify_sequence $thread_id
            return false

        } else {

            ::ngis::logger emit "posting task '[dict get $task_d task]' for job [self]"

            # Communications among threads need to know which thread is recipient
            # of a command sent calling ::thread::send. That's why the last
            # argument passed to do_task is the thread id of the caller (returned by ::thread::id)
            
            thread::send -async $thread_id [list do_task $task_d [thread::id]]
            return true

        }
    }
```

`::ngis::Job` object asynchronously *sends* the tasks one at a time to the assigned
worker thread. When the task is done the worker thread in turn will notify its job
with the results of the task by means of the main thread's event loop.

Even though threads have a private queue of commands to be executed, a Job 
waits for a task termination before assigning a new task to the thread it holds,
since a fatal error condition in one task interrupts the whole job. After
the last task in a Job has completed a Job notifies the sequence it belong to and
tells the ThreadManager to move the thread into the idle thread queue.

Once created threads don't exit and wait for new tasks to be executed, but a
mechanism for forcing idle threads to exit after a pre-determined amount
of time spent in the idle threads queue is easy to implement.

### Job Sequences and the Job Controller

As already mentioned instances of class `::ngis::JobSequence` are actually what the Job
Controller actually manages. The central method is `::ngis::JobController::sequence_roundrobin`

```
    method sequence_roundrobin {} {
        set round_robin_procedure ""

        if {[string is true $shutdown_signal]} { return }

        if {[llength $pending_sequences] > 0} {
            set ps $pending_sequences
            foreach seq $ps {
                if {[$seq active_jobs_count] == 0} {
                    my sequence_terminates $seq
                } 
            }
        }

        if {[llength $sequence_list] == 0} { return }

        if {[$thread_master thread_is_available]} {
            if {$sequence_idx >= [llength $sequence_list]} {
                set sequence_idx 0
            }

            set seq [lindex $sequence_list $sequence_idx]
            set thread_id [$thread_master get_available_thread] 
            if {[string is false [$seq post_job $thread_id]]} {
                my move_thread_to_idle $thread_id
            }
            incr sequence_idx
            my RescheduleRoundRobin
        }
    }
```
`::ngis::JobSequences` instances are posted for execution and
placed in the `sequence_list`. The index sequence_idx points within
this list to the next job sequence whose jobs need a thread. The
thread master is polled to know whether a thread is available and in
case the thread id is fetch. This thread is therefore send to to the
job sequence by calling `$seq post_job $thread_id`. If the method
returns `false` that signals the sequence has finished its jobs, the thread
is moved back into the idle thread pool. In any case the method continues
updating the sequence index `sequence_idx` (which now points to the next
sequence in the list) and the method reschedule itself by calling the
private method `RescheduleRoundRobin`. Notice that `sequence_idx` is tested 
to detect an index overrun and in case reset to point to the first sequence
(index = 0) thus realizing a circular queue of the round robin.
