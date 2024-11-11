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
        array set handler_map [list 000 NoArguments     001 SingleArgument  \
                                    002 NoArguments     003 SingleArgument  \
                                    005 SingleArgument  007 TwoArguments    \
                                    009 SingleArgument  013 SingleArgument  \
                                    102 NoArguments     104 SingleArgument  \
                                    114 SingleArgument  501 SingleArgument]

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

    method c007 {args} {
        lassign $args e1 e2

        set message_s [format [::ngis::reports::get_fmt_string 007] $e1 $e2]
        return [my SingleLine "007" $message_s]
    }

    method TrimDescription {d} { 
        if {[string length $d] > 80} {
            set d [string range $d 0 76]
            append d "..."
        } else {
            return $d
        }
    }

    method c106 {args} {
        lassign $args jc_status tm_status

        lassign $jc_status queued njobs pending
        lassign $tm_status nrthreads nithreads

        set jobs_l {}
        if {[llength $queued] > 0} {
            set jobs_l [lmap s $queued { list   [namespace tail $s]    \
                                                [my TrimDescription [$s get_description]]     \
                                                [$s active_jobs_count] \
                                                [$s completed_jobs]    \
                                                [$s njobs]             \
                                                "queued" }]
        }
        if {[llength $pending] > 0} {
            set pending_l [lmap s $pending { list   [namespace tail $s]     \
                                                    [my TrimDescription [$s get_description]]   \
                                                    [$s active_jobs_count]  \
                                                    [$s completed_jobs]     \
                                                    [$s njobs]              \
                                                    "pending" }]
            set jobs_l [concat $jobs_l $pending_l]
        }

        set jobs_l [concat $report_a(106.capts) $jobs_l]

        if {[llength $jobs_l] > 1} {
            $data_matrix deserialize [list [llength $jobs_l] 6 $jobs_l]
            set report_txt [$report_a(106.report) printmatrix $data_matrix]

            # let's infer the report width from the first line
            set rep_width [string length [lindex $report_txt 0]]
        } else {
            set rep_width 40
            set report_txt ""
        }

        $data_matrix deserialize [list 1 1 [list [list "$nrthreads running $nithreads idle threads"]]]
        $report_bottom size 0 [expr $rep_width - 4]
        set bottom_txt [$report_bottom printmatrix $data_matrix]
 
        set m [::struct::matrix m]
        $m deserialize [list 1 1 [list {{[106] Job Sequences Status}}]]
        $report_top size 0 [expr $rep_width - 4]
        set top_txt [$report_top printmatrix $m]
        $m destroy

        return [append top_txt $report_txt $bottom_txt]
    }

    method c108 {args} {
        set entities_l [lmap e {*}$args {
            lassign $e eid description nrecs
            list $eid [my TrimDescription $description] $nrecs
        }]

        set entities_l [concat $report_a(108.capts) $entities_l]
        if {[llength $entities_l] > 0} {
            $data_matrix deserialize [list [llength $entities_l] 3 $entities_l]
            set report_txt [$report_a(108.report) printmatrix $data_matrix]
            set rep_width [string length [lindex $report_txt 0]]
        } else {

        }
        set m [::struct::matrix m]
        $m deserialize [list 1 1 [list {{[108] List of Entities}}]]
        $report_top size 0 [expr $rep_width - 4]
        set top_txt [$report_top printmatrix $m]
        $m destroy

        return [append top_txt $report_txt]
    }

    method c110 {args} {
        set tasks_l {*}$args

        set tasks_l [concat $report_a(110.capts) $tasks_l]
        if {[llength $tasks_l] > 0} {
            $data_matrix deserialize [list [llength $tasks_l] 5 $tasks_l]
            set report_txt [$report_a(110.report) printmatrix $data_matrix]
            set rep_width [string length [lindex $report_txt 0]]

            set fstring [::ngis::reports::get_fmt_string 110]

            $data_matrix deserialize [list 1 1 [list [list "\[110\] [format $fstring [llength $tasks_l]]"]]]
            $report_bottom size 0 [expr $rep_width - 4]
            set bottom_txt [$report_bottom printmatrix $data_matrix]

            $data_matrix deserialize [list 1 1 [list {{[110] Registered Tasks}}]]
            $report_top size 0 [expr $rep_width - 4]
            set top_txt [$report_top printmatrix $data_matrix]

            return [append top_txt $report_txt $bottom_txt]
        } else {

            # it never should get to here....

            return [my SingleLine "110" "No tasks registered"]
        }
    }

    method c112 {args} {
        set whos_l {*}$args
        set whos_l [concat $report_a(112.capts) $whos_l]

        $data_matrix deserialize [list [llength $whos_l] 5 $whos_l]
        set report_txt [$report_a(112.report) printmatrix $data_matrix]
        set rep_width [string length [lindex $report_txt 0]]

        set fstring [::ngis::reports::get_fmt_string 112]

        $data_matrix deserialize [list 1 1 [list [list "\[112\] [format $fstring [expr [llength $whos_l] -1]]"]]] 
        $report_top size 0 [expr $rep_width - 4]
        set top_txt [$report_top printmatrix $data_matrix]

        return [append top_txt $report_txt]
    }

    method c114 {args} {
        set jobs_l {*}$args
        if {[llength $jobs_l] == 0} { return [my SingleLine "114" "No Jobs Running"] }

        set jobs_t $report_a(114.capts)
        foreach jl $jobs_l {
            lassign $jl gid descr uri_type version job_status timestamp
            lappend jobs_t [list $gid           \
                                 [::ngis::utils::string_truncate $descr 60] \
                                 $uri_type      \
                                 $version       \
                                 $job_status    \
                                 [::ngis::utils::delta_time_s [expr [clock seconds] - $timestamp]]]
        }

        $data_matrix deserialize [list [llength $jobs_t] 6 $jobs_t]
        set report_txt [$report_a(114.report) printmatrix $data_matrix]
        set rep_width [string length [lindex $report_txt 0]]

        set fstring [::ngis::reports::get_fmt_string 114]

        $data_matrix deserialize [list 1 1 [list [list "\[114\] [format $fstring [llength $jobs_l]]"]]]
        $report_top size 0 [expr $rep_width - 4]
        set top_txt [$report_top printmatrix $data_matrix]
        return [append top_txt $report_txt]
    }

    method c116 {args} {
        set services_l {*}$args
        if {[llength $services_l] == 0} { return [my SingleLine "116" "No services found"] }

        set service_fields_l {gid uuid description uri uri_type version}
        array set legend_a [list gid gid description Description uri URL uri_type Type version Version uuid uuid]
        set fstring [::ngis::reports::get_fmt_string 116]

        set reports_pack_l {}
        foreach serv_d $services_l {
            set service_table_l [lmap f $service_fields_l { list $legend_a($f) [dict get $serv_d $f] }]

            $data_matrix deserialize [list [llength $service_table_l] 2 $service_table_l]
            set report_txt [$report_a(116.report) printmatrix $data_matrix]
            # assuming the first line to representative of the report actual width
            set rep_width [string length [lindex $report_txt 0]]

            set serv_descr [dict get $serv_d description]
            if {[string trim $serv_descr] == ""} { set serv_descr "gid service [dict get $serv_d gid]" }
            $data_matrix deserialize [list 1 1 [list [list "\[116\] $serv_descr"]]]
            $report_top size 0 [expr $rep_width - 4]
            set top_txt [$report_top printmatrix $data_matrix]

            lappend reports_pack_l [append top_txt $report_txt]
        }
        return [join $reports_pack_l "\n"]
    }
}

package provide ngis::hrformat 0.5

