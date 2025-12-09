# 

    proc identify {} {
        return [list {congruence} {data_congruence} {Record Data Congruence Check} ]
    }

    proc data_congruence {task_d tmp_space uuid_space} {

        # TODO: this actually exposes an implementation detail

        set job_d [dict get $task_d job]

        foreach p [list uri uri_original entity description] {
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
                        if {$p == "uri"} {
                            return [::ngis::tasks::make_error_result "undefined_uri" "Undefined URI"]
                        } else {
                            return [::ngis::tasks::make_error_result "undefined_uri_original" "Undefined Original URI"]
                        }
                    }
                }
            }
        }

        set uri_original [dict get $job_d uri_original]
        set query  [dict get [::uri::split $uri_original] query]
        set query_d [concat {*}[lmap a [split $query "&"] { split $a "=" }]]

        dict with query_d {
            # Checking WFS and WMS services: a WFS service can't have version 1.3.0
            # and a WMS service can't have the versions 2.0.0, 1.1.0, 1.0.0
            if {[info exists service] && [info exists version]} {
                if {(([string tolower $service] == "wfs") && ($version == "1.3.0")) ||\
                    (([string tolower $service] == "wms") && ($version in [list "2.0.0" "1.1.0" "1.0.0"]))} {
                    return [::ngis::tasks::make_error_result "service_version_mismatch" "Map service/version mismatch"]
                }
            }
        }

        # we signal the inconsistent form of the URI that should not
        # refer to both WMS and WFS classes at the same time

        set original_uri [string tolower [dict get $job_d uri_original]]
        set wms_idx [string first "wms" $original_uri]
        set wfs_idx [string first "wfs" $original_uri]
        if {($wms_idx > 0) && ($wfs_idx > 0)} {
            return [::ngis::tasks::make_warning_result "ambiguous_url_form" "" "The URL should not contain references to different map services"]
        }

        return [::ngis::tasks::make_ok_result "Service Data congruence passed"]
    }

