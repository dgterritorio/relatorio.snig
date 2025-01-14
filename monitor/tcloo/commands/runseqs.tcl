# runseqs.tcl --
#
# list running sequences. First level introspection command. It lists
# all running sequences displaying the number of jobs, the total number
# of jobs to be carried out and the sequence status
#

namespace eval ::ngis::client_server {

    ::oo::class create Runseqs {

        method exec {args} {
            set jc_status [[$::ngis_server get_job_controller] status]
            set tm_status [[$::ngis_server get_job_controller] status "thread_master"]
            return [list c106 $jc_status $tm_status]
        }
    }

    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd RUNSEQ cmd QUERY has_args no description "Query Sequence Execution Status" help qs.md]
        }
        proc mk_cmd_obj {} {
            return [::ngis::client_server::Runseqs create ::ngis::clicmd::QUERY]
        }
    }
}
