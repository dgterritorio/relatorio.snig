# 

    proc identify {} {
        return [list {congruence} {data_congruence} {Record Data Congruence Check} ]
    }

    proc data_congruence {task_d tmp_space uuid_space} {

        # TODO: this actually exposes an implementation detail

        set job_d [dict get $task_d job]

        foreach p [list uri entity description] {
            switch $p {
                entity -
                description {
                    if {!([dict exists $job_d $p] && ([dict get $job_d $p] != ""))} {
                        return [::ngis::tasks::make_warning_result "undefined_$p" "" "Undefined description"]
                    }
                }
                uri_original -
                uri {
                    # regexp simplified to avoid to check case sensitive cases
                    set uri_re {^(((ht|f)tp(s?))\:\/\/)((\d+\.\d+\.\d+\.\d+)|([a-z0-9\-]+\.)*[a-z]+)(\:[0-9]+)*(\/($|[a-z0-9\.\,\;\?\'\\\+&%\$#\=~_\-]+))*$}
                    if {[dict exists $job_d $p]} {
                        if {[regexp -nocase $uri_re [dict get $job_d $p]] == 0} {
                            return [::ngis::tasks::make_error_result "invalid_uri" "Invalid URI"]
                        }
                    } else {
                        return [::ngis::tasks::make_error_result "undefined_uri" "Undefined URI"]
                    }
                }
            }
        }
        return [::ngis::tasks::make_ok_result "Service Data congruence passed"]
    }

