# -- HRFormat
#
#
package require ngis::common
package require struct::matrix
package require ngis::utils

oo::class create ::ngis::HRFormat

oo::define ::ngis::HRFormat {
    variable report_a
    variable report_top
    variable report_bottom
    variable single_line
    variable captions_a
    variable data_matrix
    variable handler_map

    constructor {} {
        array set handler_map [list 100 NoArguments     101 SingleArgument  \
                                    102 NoArguments     103 SingleArgument  \
                                    105 NoArguments     \
                                    109 SingleArgument  113 SingleArgument  \
                                    104 SingleArgument  120 NoArguments     \
                                    114 SingleArgument  501 SingleArgument  \
                                    502 NoArguments]

        set data_matrix         [::struct::matrix hr_report_m]
        array set report_a      [array get ::ngis::reports::report_a]

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

    method c107 {args} {
        lassign $args e1 e2

        set message_s [format [::ngis::reports::get_fmt_string 107] $e1 $e2]
        return [my SingleLine "107" $message_s]
    }

    # methods that can be mixed-in (overriden)
    # by different forms of data representation

    method StringLength {str} { return [string length $str] }

    method highlight {code str} {
        set code [string trim [string tolower $code]]
        switch $code {
            ok {
                return "\x1b\[48;5;42m\x1b\[38;5;0m${str}\x1b\[m"
            }
            error {
                return "\x1b\[38;5;20m\x1b\[48;5;9m${str}\x1b\[m"
            }
            warning -
            default {
                return "\x1b\[38;5;0m\x1b\[48;5;226m${str}\x1b\[m"
            }
        }
    }

    method trim {str {limit 80}} {
        if {[my StringLength $str] > $limit} {
            return "[::ngis::utils::string_truncate $str [expr $limit - 4]]..."
        } else {
            return $str
        }
    }

    method c106 {jc_status tm_status} {

        lassign $jc_status queued njobs pending
        lassign $tm_status nrthreads nithreads

        set jobs_l {}
        if {[llength $queued] > 0} {
            set jobs_l [lmap s $queued { list   [namespace tail $s]    \
                                                [my trim [$s get_description]]     \
                                                [$s active_jobs_count] \
                                                [$s completed_jobs]    \
                                                [$s njobs]             \
                                                "queued" }]
        }
        if {[llength $pending] > 0} {
            set pending_l [lmap s $pending { list   [namespace tail $s]     \
                                                    [my trim [$s get_description]]   \
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

    method c108 {entities_l} {
        set entities_l [lmap e $entities_l {
            lassign $e eid description nrecs
            list $eid [my trim $description 80] $nrecs
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

    method c110 {tasks_l} {
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

    method c112 {whos_l} {
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

    method c114 {jobs_l} {
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

    # --------------------------------------------------------------
    # C116 procedures
    #
    # c116 procedures are for printing a table descripting a single 
    # service record
    # --------------------------------------------------------------

    method c116legend {} {
        return  [dict create   gid         gid \
                               description Description  \
                               entity_definition Entity \
                               uri         URL     \
                               uri_type    Type    \
                               version     Version \
                               uuid        uuid]
    }

    method c116single {service_d} {

        set legend_d [my c116legend]
        set service_fields_l {gid uuid description entity_definition uri uri_type version}
        set service_table_l [lmap f $service_fields_l {
            list [dict get $legend_d $f] [my trim [dict get $service_d $f]]
        }]

        set service_description [dict get $service_d description]
        if {[string trim $service_description] == ""} { set service_description "gid service [dict get $service_d gid]" }

        $data_matrix deserialize [list [llength $service_table_l] 2 $service_table_l]
        set report_txt [$report_a(two_columns) printmatrix $data_matrix]
        # assuming the first line to representative of the report actual width
        set rep_width [string length [lindex $report_txt 0]]

        $data_matrix deserialize [list 1 1 [list [list "\[116\] $service_description"]]]
        $report_top size 0 [expr $rep_width - 4]
        set top_txt [$report_top printmatrix $data_matrix]
        return [append top_txt $report_txt]
    }

    method c116 {services_l} {
        if {[llength $services_l] == 0} { return [my SingleLine "116" "No service found"] }

        set reports_pack_l {}
        foreach service_d $services_l {
            # report generation
            lappend reports_pack_l [my c116single $service_d]
        }
        return [join $reports_pack_l "\n"]
    }

    # --------------------------------------------------------------
    # C118 procedures

    method c118 {service_d registered_tasks} {
        #lassign $args service_d 
        #puts "==========\n$service_d\n========="
        #puts $service_d
        if {[dict size $service_d] == 0} { return [my SingleLine "118" "No service found"] }

        # let's extract a few information out of the service
        # a description is guaranteed to exit for a service record
        # built by ::ngis::service::service_data

        set description [dict get $service_d description]

        if {[dict exists $service_d tasks]} {
            set tasks_d [dict get $service_d tasks]
            set task_t [lmap t $registered_tasks {
                lassign $t task procedure tdescr filename language

                if {[dict exists $tasks_d $task]} {
                    set tasks_data [dict get $tasks_d $task]

                    set exit_status [dict get $tasks_data exit_status]
                    set column_real_width 10
                    set status_pad_len [expr int(($column_real_width - [string length $exit_status]) / 2)]
                    set pad [string repeat " " $status_pad_len]
                    set exit_status "${pad}${exit_status}${pad}"
                    if {[string length $exit_status] < $column_real_width} { append exit_status " " }
                    set exit_status [my highlight $exit_status $exit_status]

                    list $tdescr $exit_status [dict get $tasks_data exit_info] [dict get $tasks_data ts]
                } else {
                    continue
                }
            }]

            #puts $task_t

            set task_t [concat $report_a(118.capts) $task_t]

            $data_matrix deserialize [list [llength $task_t] 4 $task_t]
            set report_txt [$report_a(118.report) printmatrix $data_matrix]
            set rep_width [string length [lindex $report_txt 0]]

            $data_matrix deserialize [list 1 1 [list [list "\[118\] $description"]]]
            $report_top size 0 [expr $rep_width - 4]
            set top_txt [$report_top printmatrix $data_matrix]
            return [append top_txt $report_txt]
        } else {

            return [my SingleLine "118" "No tasks performed on this service"]

        }
    }

    method c122 {services_l ent_description} {
        if {[llength $services_l] == 0} { return [my SingleLine "122" "No services found"] }

        set services_t [lmap s $services_l {
            dict with s {
                set uri_d   [::uri::split $uri]
                set host    [dict get $uri_d host]

                set r [list $gid [my trim $description 40] $host $uri_type $version]
            }
            set r
        }]

        set services_t [concat $report_a(122.capts) $services_t]
        $data_matrix deserialize [list [llength $services_t] 5 $services_t]
        set report_txt [$report_a(five_columns) printmatrix $data_matrix]
        set rep_width  [string length [lindex $report_txt 0]]

        $data_matrix deserialize [list 1 1 [list [list "\[122\] '$ent_description'"]]]
        $report_top size 0 [expr $rep_width - 4]
        set top_txt [$report_top printmatrix $data_matrix]
        return [append top_txt $report_txt]
    }

}

package provide ngis::hrformat 0.5

