#
# -- erice.tcl
#
# URL handler principale del sito
#
#

package require UrlHandler
package require rwpagebroker
package require rwlogger
package require rwmenu
package require rwlink
package require ngis::conf::generator
package require ngis::configuration

namespace eval ::rwdatas {

    ::itcl::class NGIS {
        inherit UrlHandler

        public method init {args} {
            chain {*}$args
        }

        # -- to_url
        #
        # static method remapping abstract link data into real href valid arguments
        #

        public method to_url {lm} {
            set linkmodel $::rivetweb::linkmodel

            set urlargs [$linkmodel arguments $lm]
            set href [::rivetweb::composeUrl {*}$urlargs]

            # we now set the href attribute of the link

            $linkmodel set_attribute lm [list href $href]

            return $lm
        }
    }

    ::itcl::class Marshal {
        inherit NGIS

        public method init {args} {
            $this key_class_map snig_homepage ::rwpage::SnigHome    tcl/snig.tcl
            $this key_class_map snig_entity   ::rwpage::SnigEntity  tcl/snigentity.tcl
            $this key_class_map snig_service  ::rwpage::SnigService tcl/snig_service.tcl
            $this key_class_map snig_server_cmd ::rwpage::SnigCommand tcl/snig_command.tcl
            $this key_class_map snig_report_ws ::rwpage::SnigReports tcl/reports.tcl
            $this key_class_map snig_report   ::rwpage::DisplayReport tcl/snig_report.tcl
        }

        public method willHandle {arglist keyvar} {
            upvar $keyvar key 

            if {$::rivetweb::is_homepage} {
                set key snig_homepage
                return -code break -errorcode rw_ok
            } elseif {[dict exists $arglist cmd]} {
                set key snig_server_cmd
                return -code break -errorcode rw_ok
            } elseif {[dict exists $arglist service]} {
                set key snig_service
                return -code break -errorcode rw_ok
            } elseif {[dict exists $arglist eid]} {
                set key snig_entity
                return -code break -errorcode rw_ok
            } elseif {[dict exists $arglist report]} {
                set key snig_report_ws
                return -code break -errorcode rw_ok
            } elseif {[dict exists $arglist displayrep]} {
                set key snig_report
                return -code break -errorcode rw_ok
            }
            return -code continue -errorcode rw_continue
        }
    }
}

package provide ngis::roothandler 1.0

