# common.tcl --
#
# Devolving here much of the work needed to do in order
# to solve the problem of TclOO/tcl8.6 not having
# a reasonably easy way to declare common class variables.
#
#

namespace eval ::ngis {

    namespace eval protocol {
        variable CodeMessages [dict create  000     "Server is going to exit"   \
                                            001     "Unrecognized command: %s"  \
                                            002     "OK"                        \
                                            003     "Wrong arguments: %s"       \
                                            005     "Invalid service gid: %d"   \
                                            007     "Error in query: (%s) %s"   \
                                            009     "Command %s disabled"       \
                                            011     "Invalid limit on query"    \
                                            100     "Starting server"           \
                                            102     "Stopping operations"       \
                                            104     "current format %s"         \
                                            105     "Monitor Inconsistent Status" \
                                            106     "%s queued, %s pending sequences, %d jobs" \
                                            108     "%d matching entities\n%s"    \
                                            110     "%d registered tasks"      \
                                            501     "Server internal error: %s"   \
                                            503     "Missing argument for code %d"]

        proc get_fmt_string {code} {
            variable CodeMessages

            return [dict get $CodeMessages $code]
        }
    }

    namespace eval Sequences {
        variable seqn -1
        variable seq_cmd_root [namespace current]

        proc new_cmd {} {
            variable seqn
            variable seq_cmd_root
            return "${seq_cmd_root}::seq[incr seqn]"
        }

        namespace export *
        namespace ensemble create
    }

    namespace eval DataSources {
        variable dsnum -1
        variable ds_cmd_root [namespace current]

        proc new_cmd {} {
            variable dsnum
            variable ds_cmd_root [namespace current]

            return "${seq_cmd_root}::ds[incr dsnum]"
        }
    }

    namespace eval JobNames {
        variable jobn -1
        variable job_cmd_root [namespace current]

        proc new_cmd {{gid ""}} {
            variable jobn
            variable job_cmd_root

            if {$gid == ""} { }
            return "${job_cmd_root}::job[incr jobn]"
        }
        namespace export *
        namespace ensemble create
    }

    namespace eval Formatters {
        variable fmtn -1
        variable formatter_cmd_root [namespace current]

        proc new_cmd {ftype} {
            variable fmtn 
            variable formatter_cmd_root

            return "${formatter_cmd_root}::${ftype}[incr fmtn]"
        }
 
        namespace export *
        namespace ensemble create
    }

}
package provide ngis::common 1.0
