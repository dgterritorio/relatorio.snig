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
package require ngis::utils

namespace eval ::rwdatas {

    ::itcl::class NGIS {
        inherit UrlHandler

        private variable banner_menu
        private variable connection_link

        public method init {args} {
            chain {*}$args

            set banner_menu ""
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

        public method menu_list {page} {
            if {$banner_menu != ""} {
                $banner_menu destroy
            }

            set home_link   [$::rivetweb::linkmodel create $this "" \
                                                           [dict create en "Home" pt "Home"] \
                                                           "" \
                                                           [dict create en "SNIG Homepage"]]
            set banner_menu [::rwmenu::RWMenu ::rwmenu::#auto "banner" root normal]
            $banner_menu assign title "" ""
            $banner_menu add_link $home_link

            set lm $::rivetweb::linkmodel
#           if {[$page key] == "snig_entity"} {
#
#                lassign [$page entity] eid entity_definition
#                set linkobj [$lm create $this "" [dict create en $entity_definition]
#                                                 [list eid $eid] ""]
#                $banner_menu add_link $linkobj
#            }

            if {[$page key] == "snig_service"} {
                set entity [$page entity]
                if {[dict size $entity] > 0} {
                    dict with entity {
                        set entity_definition [::ngis::utils::string_truncate $entity_definition 50]

                        set linkobj [$lm create $this "" [dict create en $entity_definition] \
                                         [list eid $eid] ""]
                        $banner_menu add_link $linkobj
                    }
                }
            }

            set linkobj [$lm create $this "" [dict create en "Connections"] \
                                             [list displayrep 112] ""]
            $banner_menu add_link $linkobj
            set linkobj [$lm create $this "" [dict create en "Jobs"] \
                                             [list displayrep 114] ""]
            $banner_menu add_link $linkobj
            return [dict create banner $banner_menu]
        }
    }


    ::itcl::class Marshal {
        inherit NGIS

        public method init {args} {
            chain {*}$args
            $this key_class_map snig_homepage   ::rwpage::SnigHome    tcl/snig.tcl
            $this key_class_map snig_entity     ::rwpage::SnigEntity  tcl/snigentity.tcl
            $this key_class_map snig_service    ::rwpage::SnigService tcl/snig_service.tcl
            $this key_class_map snig_server_cmd ::rwpage::SnigCommand tcl/snig_command.tcl
            $this key_class_map snig_report_ws  ::rwpage::SnigReports tcl/reports.tcl
            $this key_class_map snig_report     ::rwpage::DisplayReport tcl/snig_report.tcl
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

