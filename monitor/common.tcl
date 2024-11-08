# common.tcl --
#
# Devolving here much of the work needed to do in order
# to solve the problem of TclOO/tcl8.6 not having
# a reasonably easy way to declare common class variables.
#
#
package require report

::report::defstyle simpletable {} {
    data set [split "[string repeat "| "   [columns]]|"]
    top  set [split "[string repeat "+ - " [columns]]+"]
    bottom  set [top get]
    top  enable
    bottom  enable
}

::report::defstyle captionedtable {{n 1}} {
    simpletable
    topdata   set [data get]
    topcapsep set [top get]
    topcapsep enable
    tcaption $n
    bottom  enable
}

namespace eval ::ngis {

    namespace eval reports {
        variable CodeMessages [dict create  000     "Server is going to exit"   \
                                            001     "Unrecognized command: %s"  \
                                            002     "OK"                        \
                                            003     "Wrong arguments: '%s'"     \
                                            005     "Invalid service gid: %d"   \
                                            007     "Error: (%s) errorcode: %s" \
                                            009     "Invalid arguments for '%s'" \
                                            013     "Invalid format '%s'"       \
                                            102     "Stopping operations"       \
                                            104     "Current format: %s"        \
                                            106     "%s queued, %s pending sequences, %d jobs" \
                                            108     "%d matching entities\n%s"  \
                                            110     "%d registered tasks"       \
                                            112     "%d Sessions Connected"     \
                                            114     "%d Job Executing"          \
                                            501     "Server internal error: %s" \
                                            503     "Missing argument for code %d"]

        variable report_top
        set report_top [::report::report hr_report_top 1 style captionedtable]
        $report_top bottom      disable
        $report_top topcapsep   disable
        $report_top justify     0 center
        $report_top pad         0 both " "

        variable report_bottom
        set report_bottom [::report::report hr_report_bottom 1 style captionedtable]
        $report_bottom top          disable
        $report_bottom topcapsep    disable
        $report_bottom justify  0   left
        $report_bottom pad      0   both " "

        variable single_line
        set single_line [::report::report hr_report_single_line 1 style captionedtable]
        $single_line topcapsep      disable
        $single_line justify    0   left

        variable report_a
        array set report_a {}

        # setup report generators

        # Job sequences status report
        set ncolumns 6
        set report_a(106.capts)     [list {"Seq ID" "Description" "Running Jobs" "Completed Jobs" "Total Jobs" "Status"}]
        set report_a(106.report)    [::report::report hr_106_data $ncolumns style captionedtable]
        for {set c 0} {$c < $ncolumns} {incr c} { $report_a(106.report) pad $c both " " }

        # Registered tasks list
        set ncolumns 5
        set report_a(110.capts)     [list {"Task" "Procedure" "Description" "Script" "Language"}]
        set report_a(110.report)    [::report::report hr_110_data $ncolumns style captionedtable]
        for {set c 0} {$c < $ncolumns} {incr c} { $report_a(110.report) pad $c both " " }

        # Connections
        set ncolumns 5
        set report_a(112.capts)     [list {"Login" "Socket" "Commands Exec." "Format" "Idle"}]
        set report_a(112.report)    [::report::report hr_112_data $ncolumns style captionedtable]
        for {set c 0} {$c < $ncolumns} {incr c} { $report_a(112.report) pad $c both " " }

        # Jobs
        set ncolumns 6
        set report_a(114.capts)     [list {"GID" "Description" "URL Type" "Version" "Status" "Timestamp"}]
        set report_a(114.report)    [::report::report hr_114_data $ncolumns style captionedtable]
        for {set c 0} {$c < $ncolumns} {incr c} { $report_a(114.report) pad $c both " " }

        # Entities
        set ncolumns 3
        set report_a(108.capts)     [list {"Eid" "Description" "Records"}]
        set report_a(108.report)    [::report::report hr_108_data $ncolumns style captionedtable]
        for {set c 0} {$c < $ncolumns} {incr c} { $report_a(108.report) pad $c both " " }

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

            return "${ds_cmd_root}::ds[incr dsnum]"
        }
        namespace export *
        namespace ensemble create
    }

    namespace eval JobNames {
        variable job_cmd_root [namespace current]
        variable job_cmd_pattern "${job_cmd_root}::job"

        proc cmd_pattern {} {
            variable job_cmd_pattern
            return $job_cmd_pattern
        }

        proc new_cmd {{gid ""}} {
            variable job_cmd_root

            if {$gid == ""} { }
            set proposed "[cmd_pattern]${gid}"
            set modifier 0
            while {[info command $proposed] != ""} {
                # set a limit to multiple jobs for the same resource
                if {$modifier > 20} {
                    return -code error -errorcode too_many_jobs "Too many jobs for the same gid $gid"
                }
                set proposed "[cmd_pattern]${gid}-[incr modifier]"
            }
            return $proposed
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
