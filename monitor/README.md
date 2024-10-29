**SNIG Services Monitor Internals**

Monitor Server Application Structure.

The Monitor Server is an asynchronous standalone application that uses
an event loop controlled within the class ::ngis::Server to synchronize
and perform most operations. 

Socket connections (either TCP/IP or Unix Socket connections) events are
processed by the
```
  +-------------+    +--------------+
  |  TCP/IP     |    |  Unix Socket |  <--- | Daily Job | 
  |  connection |    |  Connection  |  <--- | CLI Client|
  +-------------+    +--------------+
        |                   |
        |                   |
  +---------------------------------------------+
  |                                             |       +----------------+
  |          ::ngis::Server Event Queue         | <---- | Thread Manager |
  |                                             |       +----------------+
  +---------------------------------------------+
         ^            ^
         |            |
  +-----------+ +-----------+
  |    Job    | |    Job    |
  | Sequence1 | | Sequence2 |
  +-----------+ +-----------+



```
