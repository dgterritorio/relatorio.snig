# --snig

package require ngis::webservice

namespace eval ::rwpage {
    ::itcl::class SnigCommand {
        inherit SnigWebService

        constructor {key} {SnigWebService::constructor $key} {
        }

    }
}
