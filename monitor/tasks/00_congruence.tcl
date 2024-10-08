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
                uri {
                    if {!([dict exists $job_d $p] && ([dict get $job_d $p] != ""))} {
                        return [::ngis::tasks::make_error_result "missing_url" "" "Undefined url for gid [$job_d gid]"]
                    }
                }
            }
        }
        return [::ngis::tasks::make_ok_result "Record data congruence tested"]
    }

