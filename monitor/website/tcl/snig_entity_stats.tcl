package require ngis::page
package require json
package require form

namespace eval ::rwpage {
    ::itcl::class EntityStats {
        inherit SnigPage
        private variable report_n
        private variable eid
        private variable hash
        private variable entities_d
        private variable report_queries_schema
        private variable results_set

        # variable used to control the output
        private variable section_range
        private variable current_section
        private variable results_a

        constructor {key} {SnigPage::constructor $key} {
            array set results_a {}
            ::ngis::configuration::readconf report_queries_schema
            set results_set ""
        }

        proc entity_query_select_form {form_response} {
            upvar 1 $form_response formdefaults

            if {$hash == ""} {
                set formurl [::rivetweb::composeUrl statseid $eid]
            } else {
                set formurl [::rivetweb::composeUrl stats $hash]
            }

            set form [form [namespace current]::confirm_sub -method     POST                    \
                                                            -action     $formurl                \
                                                            -defaults   formdefaults            \
                                                            -enctype    "multipart/form-data"]

            $form start
            set section_keys [lsort -integer [dict keys $::ngis::reports::sections_d]]
            $form select section -values $section_keys -labels [lmap k $section_keys {
                dict get $::ngis::reports::sections_d $k description 
            }]
            $form submit submit -value "Query"
            $form end
            $form destroy
        }

        public method prepare_page {language argsqs} {
            set dbhandle [$this get_dbhandle]
            set eid     [dict get $argsqs statseid]
            set section [::rivet::var_post get section 1]
            set hash    ""
            if {[dict exists $argsqs stats]} {
                set hash [dict get $argsqs stats]
            }

            set result_set [$dbhandle list "SELECT description from testsuite.entities where eid=$eid"]
            if {$result_set == ""} {
                return -code error -errorcode invalid_eid "Invalid Entity id"
            }

            lassign $result_set entity_description
            $this title $language $entity_description

            set args_posted [::rivet::var_post all]

            if {$results_set != ""} {
                catch { $results_set destroy }
                set results_set ""
            }
            array unset results_a
            set current_section ""

            set current_section [::ngis::reports::get_section $section]
            set section_range [dict get $current_section range]
            array unset results_a
            foreach qi $section_range {
                set results_l {}
                set sql "SELECT * from ${report_queries_schema}.[::ngis::reports::get_view $qi] WHERE eid=$eid"
                #puts $sql
                set results_set [$dbhandle exec $sql]
                if {[$results_set error]} {
                    return -code error -errorcode sql_error "error in SQL query '$sql'" 
                } else {
                    if {[$results_set numrows] > 0} {
                        while {[$results_set next -dict d]} {
                            lappend results_l $d
                        }
                    } else {
                        #set results_a($qi) "No data"
                        continue
                    }
                }
                set results_a($qi) $results_l
            }
            $this close_dbhandle
        }

        private method report_4 {k v} {
            set attr ""
            if {$k == "status_code_definition"} {
                if {$v != "OK"} {
                    set attr [list class taskerror]
                }
            }
            return $attr
        }

        private method report_9 {k v} {
            if {$k == "result_code"} {
                switch -nocase $v {
                    error {
                        return [list class taskerror]
                    }
                    warning {
                        return [list class taskwarning]
                    }
                    ok {
                        return [list class taskok]
                    }
                }
            }
            return ""
        }

        private method transform_table {report_n table_rows_l} {
            set transformer "[namespace current]::report_${report_n}"

            # we exploit the Itcl info method in order
            # to understand if a table transformer exists

            if {$transformer in [$this info function]} {
                return [lmap r $table_rows_l {
                    lmap {k v} $r {
                        $transformer $k $v
                    }
                }]
                return [$transformer $table_rows_l]
            } else {
                return [lrepeat [llength $table_rows_l] ""]
            }
        }

        public method print_content {language} {
            #set args_s [lmap {k v} [$this url_args] { list $k $v }]
            #puts [::rivet::xml "URL encoded: [join $args_s \n]" pre]
            #set args_s [lmap {k v} [::rivet::var_post all] { list $k $v }]
            #puts [::rivet::xml "POST encoded: [join $args_s \n]" pre]
            
            array set response_post [::rivet::var_post all]

            $this entity_query_select_form response_post

            set template_o [::rivetweb::RWTemplate::template $::rivetweb::template_key]
            set ns [$template_o formatters_ns]

            if {[llength [array names results_a]] > 0} {
                foreach qi $section_range {
                    set columns     [::ngis::reports::get_report_columns $qi [dict keys [lindex $results_a($qi) 0]]]
                    set rows_l      [lmap r $results_a($qi) { dict filter $r key {*}$columns }]
                    #puts [::rivet::xml "columns = $columns" pre]

                    set captions                [::ngis::reports::get_captions $columns $language]
                    set table_body_attributes   [$this transform_table $qi $rows_l]
                    set table_body_rows         [lmap r $rows_l { dict values $r }]
                    set top_header              "[::ngis::reports::get_table_header $qi] ($qi)"

                    #puts [::rivet::xml "qi = $qi" pre]
                    puts [${ns}::mk_table $captions $table_body_rows $top_header $table_body_attributes]
                }
            } else {
                puts [::rivet::xml "No data found for '[dict get $current_section description]'" div]
            }
        }
    }
}
