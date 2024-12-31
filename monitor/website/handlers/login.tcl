

package require UrlHandler
package require ngis::roothandler

namespace eval ::rwdatas {

    ::itcl::class Login {
        inherit NGIS

        public method init {args} {
            chain {*}$args
        }


    }
}
