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
package require ngis::utils

namespace eval ::rwdatas {

    ::itcl::class NGIS {
        inherit UrlHandler

        private variable banner_menu
        private variable connection_link

        private common dbhandle
        private common session_obj

        private common error_page
        private common dbuser
        private common dbhost
        private common dbname
        private common dbpasswd
        private common dbms_driver

        public proc attempt_db_connect {} {
            if {![info exists dbhandle]} {
                set connectcmd  [list ::DIO::handle {*}$dbms_driver -user $dbuser -db $dbname -host $dbhost -pass $dbpasswd]
                set ::dbms      [eval $connectcmd]
                set dbhandle    $::dbms
            }
            return $dbhandle
        }

        public proc close_db_connection {} {
            if {[info exists dbhandle]} {
                $dbhandle destroy
                unset dbhandle
            }
        }

        public proc get_session_obj {args} {

            # the common variable 'session_obj' is used to
            # determine if all common variables have to be
            # initialized

            if {![info exists session_obj]} {

                foreach v {dbuser dbhost dbname dbpasswd} {
                    ::ngis::configuration readconf $v $v
                }
                set error_page  ""
                set dbms_driver [::ngis::configuration readconf dbms_driver]

                set dbhandle [attempt_db_connect]
                set session_obj [Session ::SESSION  -dioObject              $dbhandle   \
                                                    -debugMode              0           \
                                                    -gcMaxLifetime          [expr 7200 + 3600]    \
                                                    -sessionLifetime        [expr 3600 + 3600]    \
                                                    -sessionRefreshInterval 1800    \
                                                    -entropyFile            /dev/urandom \
                                                    -entropyLength          10      \
                                                    -gcProbability          2       \
                                                    -sessionTable           "testsuite.rivet_session" \
                                                    -sessionCacheTable      "testsuite.rivet_session_cache" \
                                                    -scrambleCode           [clock format [clock seconds] -format "%S"]]

            }

            return $session_obj
        }

        public proc is_logged {} {
            set session_obj [get_session_obj]
            set login_d [$session_obj load status]
            if {[dict exists $login_d logged]} {
                return [dict get $login_d logged]
            }
            return 0
        }

        public proc check_password {login password} {
            ::ngis::configuration readconf users_table users_table

            set tdbc_res [::ngis::service::exec_sql_query \
                "select userid from testsuite.snig_users where login='$login' and password = crypt('$password',password)"]

            return [$tdbc_res rowcount]
        }

        # Instance methods

        public method init {args} {
            chain {*}$args
            set banner_menu ""

            get_session_obj
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

            set home_link [$::rivetweb::linkmodel create $this "" [dict create en "Home" pt "Home"] \
                                                               "" [dict create en "SNIG Homepage"]]
            set banner_menu [::rwmenu::RWMenu ::rwmenu::#auto "banner" root normal]
            $banner_menu assign title "" ""
            $banner_menu add_link $home_link

            set lm $::rivetweb::linkmodel

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

            if {[is_logged]} {
                set linkobj [$lm create $this "" [dict create en "Estatisticas"] \
                                                 [list show estatisticas] ""]
                $banner_menu add_link $linkobj
                set linkobj [$lm create $this "" [dict create en "Connections"] \
                                                 [list displayrep 112] ""]
                $banner_menu add_link $linkobj
                set linkobj [$lm create $this "" [dict create en "Jobs"] \
                                                 [list displayrep 114] ""]
                $banner_menu add_link $linkobj
                set linkobj [$lm create $this "" [dict create en "Create User"] \
                                                 [list newuser 1] ""]
                $banner_menu add_link $linkobj
                set linkobj [$lm create $this "" [dict create en "Users List"] \
                                                 [list userlist 1] ""]
                $banner_menu add_link $linkobj
                set linkobj [$lm create $this "" [dict create en "Logout"] \
                                                 [list logout 1] ""]
                $banner_menu add_link $linkobj
            }

            return [dict create banner $banner_menu]
        }
    }


    ::itcl::class Marshal {
        inherit NGIS

        public method init {args} {
            chain {*}$args
            $this key_class_map snig_homepage   ::rwpage::SnigHome      tcl/snig.tcl
            $this key_class_map snig_entity     ::rwpage::SnigEntity    tcl/snig_entity.tcl
            $this key_class_map snig_service    ::rwpage::SnigService   tcl/snig_service.tcl
            $this key_class_map snig_server_cmd ::rwpage::SnigCommand   tcl/snig_command.tcl
            $this key_class_map snig_report_ws  ::rwpage::SnigReports   tcl/reports.tcl
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

        public method menu_list {page} {
            return [dict create]
        }
    }
}

package provide ngis::roothandler 1.0

