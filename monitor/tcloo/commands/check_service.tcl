# check_service.tcl
#
# Class CheckService implements protocol command CHECK that launches
# sequences of jobs over selected sets of GIS services
#
#

namespace eval ::ngis::client_server {

    ::oo::class create CheckService {

        method SingleServiceChecks {services_l} {
            set jseq_des "Series of [llength $service_l] records"
            # if it's a single service job we set as job sequence description
            # the 'description' columns in table uris_long
            if {[llength $service_l] == 1} {
                set jseq_des [::ngis::service get_description [lindex $service_l 0]]
            }
            $job_controller post_sequence [::ngis::JobSequence create [::ngis::Sequences new_cmd]   \
                            [::ngis::PlainJobList create [::ngis::DataSources new_cmd] $service_l]  \
                            $jseq_des]
        }

        method EntityCheck {eid} {
            set entity_d [::ngis::service load_entity_record $eid]
            if {[dict size $entity_d] > 0} {
                set entity [::ngis::service::entity get_description $entity_d]
                set resultset [::ngis::service load_by_entity $eid -resultset]
                $job_controller post_sequence [::ngis::JobSequence create [::ngis::Sequences new_cmd] \
                                [::ngis::DBJobSequence create [::ngis::DataSources new_cmd] $resultset] $entity]
            } else {
                ::ngis::logger emit "No entity record found for eid $eid"
            }
        }

        method exec {args} {
            set parsed_results [lassign [::ngis::utils::resource_check_parser $args] res_status]
            if {$res_status == "OK"} {
                lassign $parsed_results gids_l eids_l entities_l

                # 
                if {[llength $gids_l] > 0} {
                    set service_l [::ngis::service load_series_by_gids $gids_l]
                    if {[llength $service_l] > 0} {
                        my SingleServiceChecks $service_l
                    } else {
                        return [list c105]
                    }
                }

                # 
                if {[llength $eids_l] > 0} {
                    foreach eid $eids_l {
                        my EntityCheck $eid
                    }
                }

                #
                if {[llength $entities_l]} {
                    foreach entity $entities_l {
                        set eid [lindex $entity 0]
                        my EntityCheck $eid
                    }
                }

                return [list c102]
            } else {
                lassign $parsed_results code a
                return [list c${code} $a]
            }
        }
    }

    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd CHECK cmd CHECK has_args yes description "Starts Monitoring Jobs" help check.md]
        }

    }

}
