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

                    set rfc3986_uri_re {^(((ht|f)tp(s?))\:\/\/)((\d+\.\d+\.\d+\.\d+)|([a-z0-9\-]+\.)*[a-z]+)(\:[0-9]+)*(\/($|[a-z0-9\.\,\;\?\'\\\+&%\$#\=~_\-]+))*$}
                    if {[dict exists $job_d $p]} {
                        set uri [dict get $job_d $p]


                        if {[regexp -nocase $rfc3986_uri_re $uri] == 0} {

                            # let's see if it might contain the {...} arguments of a RFC 6570 template 
                            set rfc6570_args [regexp -all {\/\{[a-zA-Z0-9_]\}} $uri]
                            if {$rfc6570_args == 3} {
                                # yes, it looks like we are checking a RFC 6570 template.
                                return [::ngis::tasks::make_warning_result "possible_RFC6570_template" "" "Possible RFC 6570 URI"]
                            }

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

