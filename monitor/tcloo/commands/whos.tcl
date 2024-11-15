# whos.tcl
#
#

namespace eval ::ngis::client_server {

    ::oo::class create Whos {
        method exec {args} {
            return [list c112 [$::ngis_server whos]]
        }
    }

    namespace eval tmp {
        proc identify {} {
            return [dict create cli_cmd WHOS cmd WHOS has_args no description "List Active Connections" help w.md]
        }
        proc mk_cmd_obj {} {
            return [::ngis::client_server::Whos create ::ngis::clicmd::WHOS]
        }
    }
}
