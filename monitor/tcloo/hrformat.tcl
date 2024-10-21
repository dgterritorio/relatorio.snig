# -- HRFormat
#
#
package require struct::matrix
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

oo::class create ngis::HRFormat

oo::define ngis::HRFormat {
    variable report_a
    variable report_top
    variable report_bottom
    variable captions_a
    variable data_matrix

    constructor {} {
        set data_matrix [::struct::matrix htformat_m]
        array set report_a {}

        set report_top [::report::report hr_report_top 1 style captionedtable]
        $report_top bottom      disable
        $report_top topcapsep   disable
        $report_top justify     0 center
        set report_bottom [::report::report hr_report_bottom 1 style captionedtable]
        $report_bottom top         disable
        $report_bottom topcapsep   disable
        $report_bottom justify     0 left

        set single_line [::report::report hr_report_single_line 1 style captionedtable]
        $single_line topcapsep   disable
        $single_line justify     0 left
 
        set report_a(106.capts) [list {"Seq id" "Description" "Jobs" "Status"}]
        set report_a(106.data)  [::report::report hr_106_data 4 style captionedtable]
        $report_a(106.data) pad 0 both " "
        $report_a(106.data) pad 1 both " "
        $report_a(106.data) pad 2 both " "
        $report_a(106.data) pad 3 both " "

        set report_a(110.capts) [list {"Task" "Procedure" "Description" "Script" "Language"}]
        set report_a(110.data) [::report::report hr_110_data 5 style captionedtable]
        $report_a(110.data) pad 0 both " "
        $report_a(110.data) pad 1 both " "
        $report_a(110.data) pad 2 both " "
        $report_a(110.data) pad 3 both " "
        $report_a(110.data) pad 4 both " "

        set report_a(002.data) [::report::report hr_report 1 style captionedtable]
        $report_a(002.data) topcapsep disable
        $report_a(002.data) size      0 40
        #$report_a(002.data) justify   0 center
    }

    destructor {
        $data_matrix destroy
    }

    method format {} { return "HR" }

    method SingleLine {code message_s} {
        set message_s "\[$code\] $message_s"
        $data_matrix deserialize [list 1 1 [list [list $message_s]]]
        $single_line size 0 [expr [string length 0 [string length $message_s]]]
        return [$single_line printmatrix $data_matrix]
    }

    method c002 {args} {
        set m [::struct::matrix m]
        $m deserialize [list 1 1 [list {{[002] OK}}]]
        set res002 [$report_a(002.data) printmatrix $m]
        $m destroy
        return $res002
    }

    method c106 {args} {
        lassign $args jobs_l tm_status
        lassign $tm_status nrthreads nithreads

        # assuming the job table had *4* columns (determined by ::ngis::Protocol)

        set jobs_l [concat $report_a(106.capts) $jobs_l]
        if {[llength $jobs_l] > 1} {
            $data_matrix deserialize [list [llength $jobs_l] 4 $jobs_l]
            set report_txt [$report_a(106.data) printmatrix $data_matrix]

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

    method c110 {args} {
        set tasks_l [lindex $args 0]

        set tasks_l [concat $report_a(110.capts) $tasks_l]
        if {[llength $tasks_l] > 0} {
            $data_matrix deserialize [list [llength $tasks_l] 5 $tasks_l]
            set report_txt [$report_a(110.data) printmatrix $data_matrix]
            return $report_txt
        } else {
            return ""
        }
    }

    method c104 {} {
    }
    

}

package provide ngis::hrformat 0.5

