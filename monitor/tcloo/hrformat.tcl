# -- HRFormat
#
#
package require struct::matrix
package require ngis::common

oo::class create ngis::HRFormat

oo::define ngis::HRFormat {
    variable report_a
    variable report_top
    variable report_bottom
    variable single_line
    variable captions_a
    variable data_matrix
    variable handler_map

    constructor {} {
        array set handler_map [list 009 SingleArgument 003 SingleArgument \
                                    001 SingleArgument 503 SingleArgument \
                                    005 SingleArgument 102 NoArguments    \
                                    002 NoArguments    104 SingleArgument \
                                    000 NoArguments    007 TwoArguments   \
                                    501 SingleArgument]

        set data_matrix [::struct::matrix htformat_m]
        array set report_a [array get ::ngis::reports::report_a]

        set report_top      $::ngis::reports::report_top
        set report_bottom   $::ngis::reports::report_bottom
        set single_line     $::ngis::reports::single_line
    }

    destructor {
        $data_matrix destroy
    }

    method format {} { return "HR" }

    method unknown {target args} {
        # extract the code from the target name
        # 

        if {[regexp {c(\d+)} $target -> code] == 0} {
            return -code error -errorcode invalid_target -errorinfo "Error: unknown target '$target'"
        }

#       handler_map is the last resort for resolving the error handler
#
        if {[info exists handler_map($code)]} {

            switch $handler_map($code) {
                NoArguments {
                    set message_s [::ngis::reports::get_fmt_string $code]
                    return [my SingleLine $code $message_s]
                }
                SingleArgument {
                    if {[llength $args] > 0} {
                        set message_s [format [::ngis::reports::get_fmt_string $code] [lindex $args 0]]
                        return [my SingleLine $code $message_s]
                    }
                }
                TwoArguments {
                    lassign $args a1 a2 
                    set message_s [format [::ngis::reports::get_fmt_string $code] $a1 $a2]
                    return [my SingleLine $code $message_s]
                }
                default {
                    return -code error -errorcode unhandler_error -errorinfo "Internal Server Error: unknown target '$target'"
                }
            }
        } else {
            return -code error -errorcode invalid_target -errorinfo "Error: unknown target '$target'"
        }

    }

    method SingleLine {code message_s} {
        set message_s "\[$code\] $message_s"
        $data_matrix deserialize [list 1 1 [list [list $message_s]]]
        $single_line size 0 [expr max(80,[string length $message_s])]
        return [$single_line printmatrix $data_matrix]
    }

    method c106 {args} {
        lassign $args jc_status tm_status

        lassign $jc_status queued njobs pending
        lassign $tm_status nrthreads nithreads

        set jobs_l {}
        if {[llength $queued] > 0} {
            set jobs_l [lmap s $queued { list $s [$s get_description] [$s active_jobs_count] "queued" }]
        }
        if {[llength $pending] > 0} {
            set pending_l [lmap s $pending { list $s [$s get_description] [$s active_jobs_count] "pending" }]
            set jobs_l [concat $jobs_l $pending_l]
        }

        # assuming the job table had *4* columns (determined by ::ngis::Protocol)

        set jobs_l [concat $report_a(106.capts) $jobs_l]
        if {[llength $jobs_l] > 1} {
            $data_matrix deserialize [list [llength $jobs_l] 4 $jobs_l]
            set report_txt [$report_a(106.report) printmatrix $data_matrix]

            # let's infer the report width from the first line 

            set rep_width [string length [lindex $report_txt 0]]
        } else {
            set rep_width 40
            set report_txt ""
        }

        $data_matrix deserialize [list 1 1 [list [list "$nrthreads running $nithreads idle threads"]]]
        $report_bottom size 0 [expr $rep_width - 2]
        set bottom_txt [$report_bottom printmatrix $data_matrix]
 
        set m [::struct::matrix m]
        $m deserialize [list 1 1 [list {{[106] Job Sequences Status}}]]
        $report_top size 0 [expr $rep_width - 2]
        set top_txt [$report_top printmatrix $m]
        $m destroy

        return [append top_txt $report_txt $bottom_txt]
    }

    method c108 {args} {
        set entities_l [concat $report_a(108.capts) $args]

        if {[llength $entities_l] > 0} {
            $data_matrix deserialize [list [llength $entities_l] 2 $entities_l]
            set report_txt [$report_a(108.report) printmatrix $data_matrix]
            set rep_width [string length [lindex $report_txt 0]]
        } else {

        }
        set m [::struct::matrix m]
        $m deserialize [list 1 1 [list {{[108] Entities}}]]
        $report_top size 0 [expr $rep_width - 2]
        set top_txt [$report_top printmatrix $m]
        $m destroy

        return [append top_txt $report_txt]
    }

    method c110 {args} {
        set tasks_l $args

        set tasks_l [concat $report_a(110.capts) $tasks_l]
        if {[llength $tasks_l] > 0} {
            $data_matrix deserialize [list [llength $tasks_l] 5 $tasks_l]
            set report_txt [$report_a(110.report) printmatrix $data_matrix]
            set rep_width [string length [lindex $report_txt 0]]

            set fstring [::ngis::reports::get_fmt_string 110]

            $data_matrix deserialize [list 1 1 [list [list [format $fstring [llength $tasks_l]]]]]
            $report_bottom size 0 [expr $rep_width - 4]
            set bottom_txt [$report_bottom printmatrix $data_matrix]

            $data_matrix deserialize [list 1 1 [list {{[110] Registered Tasks}}]]
            $report_top size 0 [expr $rep_width - 4]
            set top_txt [$report_top printmatrix $data_matrix]

            return [append top_txt $report_txt $bottom_txt]
        } else {

            # it never should get to here....

            return [SingleLine "110" "No tasks registered"]
        }
    }
}

package provide ngis::hrformat 0.5

