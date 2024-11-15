# joblist.tcl --
#
# implementation of protocol command JOBLIST
#

namespace eval ::ngis::client_server {

    ::oo::class create Joblist {
        method exec {args} {
            set job_controller [$::ngis_server get_job_controller]
            set job_sequences [$job_controller job_sequences]
            set jobs_l [lmap s $job_sequences {
                set aj [$s active_jobs]
                lmap j $aj {
                    set sj [$j serialize]
                    dict with sj {
                        list $gid $description $uri_type $version $job_status $timestamp
                    }
                }
            }]
            set jobs_l [eval concat $jobs_l]
            return [list c114 $jobs_l]
        }
    }

    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd JOBLIST cmd JOBLIST has_args maybe description "List Running Jobs" help jl.md]

        }
        proc mk_cmd_obj {} {
            return [::ngis::client_server::Joblist create ::ngis::clicmd::JOBLIST]
        }
    }


}

