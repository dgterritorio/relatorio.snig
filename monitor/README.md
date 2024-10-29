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
    |     ::ngis::Server (Event Queue,        | <---- | Thread Manager |
    | network, Threads and Jobs callbacks)    |       +----------------+
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
an event loop controlled within the class `::ngis::Server` to synchronize
and perform most operations. 

The server works essentially in response to events that may be either
socket connections (TCP/IP or Unix Socket connections) or server
internal events, such as single job termination, job sequence
termination and batched requests for results storage.
Event callbacks are implemented by class object methods that have
been kept as simple as possibile in order to preserve the overall
server responsiveness to any events and offer them time slices.
Some callbacks performing relatively more complex operations
where designed to fit into the asynchronous model in order to
avoid delays and thread lock-ups. 

For example the `JobController::sequence_roundrobin` method, 
which implements a round-robin mechanism attempting to evenly
distribute worker threads among *Job Sequences* (a *Job Sequence* is a
collection of *Jobs*), instead of looping over the whole pool of idle
threads, it assigns a thread to the first job sequence returned by the
round-robin alghoritm and then resubmits itself after a
configured time (default 100ms) to process the next idle thread
and assign it to a new job sequence.

The server maintains a pool of worker threads (see class
`::ngis::ThreadMaster`) to which specific tasks are devolved.
Threads are needed for executing tasks since the server leverages
external tools for dowloading and analyzing data returned by services.
These tools have CLI interfaces and don't fit into the asynchronous model of the
application. The thread manager spawns new tasks when requested (up to a
maximum number of threads set in the configuration file `ngis_monitor_conf.tcl`)
and makes them available to the job controller which in turn passes
reference of idle threads to the round-robin Job Sequences

### Job Execution and the Server Thread Pool

A *Job* is a set of tasks to be carried out for a specific service. The
service data are one of the rows that in the resultset of an SQL query
to the database. A `::ngis::Job` object asynchronously *sends* tasks
one at a time to the assigned worker thread (the set of tasks depends on the type
of the service). A worker thread in turn notifies the results of a task
through the main thread's event loop to the job that had submitted the task. 
Even though threads can handle queue of tasks a Job waits for a task
completion before sending a new task to its thread, since
a fatal error condition in one task interrupts the whole job.

Once created threads don't exit and wait for new tasks to be executed. But a
mechanism for forcing idle threads to exit after a pre-determined amount
of time spent in the idle threads queue is easy to implement.
