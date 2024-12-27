#
# -- snig.tcl
#
# Site home page

package require rwpage
package require ngis::configuration
package require DIO 2.0
package require dio_Tdbc 2.0

namespace eval ::rwpage {

    ::itcl::class SnigPage {
        inherit RWPage

        private common dbhandle
        private common session_obj

        private variable error_page
        private variable dbuser
        private variable dbhost
        private variable dbname
        private variable dbpasswd
        private variable dbms_driver

        constructor {key} {RWPage::constructor $key} {
            foreach v {dbuser dbhost dbname dbpasswd} {
                ::ngis::conf::readconf $v $v
            }
            set error_page  ""
            set dbms_driver [::ngis::conf::readconf dbms_driver]
        }

        public method init {args} {

            if {![info exists session_obj] && false} {

                set session_obj [Session ::SESSION  -debugMode              0       \
                                                    -gcMaxLifetime          7200    \
                                                    -sessionLifetime        3600    \
                                                    -sessionRefreshInterval 1800    \
                                                    -entropyFile            /dev/urandom \
                                                    -entropyLength          10      \
                                                    -gcProbability          2       \
                                                    -scrambleCode           [clock format [clock seconds] -format "%S"]]
            }

        }
        

        public method refresh {timereference} { return false }
        public method get_dbhandle {} { return $dbhandle }

        private method attempt_db_connect {} {
            if {![info exists dbhandle]} {
                set connectcmd  [list ::DIO::handle {*}$dbms_driver -user $dbuser -db $dbname -host $dbhost -pass $dbpasswd]
                set ::dbms      [eval $connectcmd]
                set dbhandle $::dbms
            }
            return $dbhandle
        }

        public method get_session {} {
            return $session_obj
        }

        private method close_db_connection {} {
            if {[info exists dbhandle]} { 
                $dbhandle destroy
                unset dbhandle
            }
        }

        public method js {} { }

        public method prepare {language argsqs} {
            RWPage::prepare $language $argsqs

            ::try {
                set dbhandle [$this attempt_db_connect]
                $session_obj configure -dioObject $dbhandle
                $this prepare_page $language $argsqs
                set page $this
            } on error {e opts} {

                if {[info command $error_page] != ""} {
                    $error_page destroy
                }

                set errorCode [dict get $opts -errorcode]
                set page_text "<b>$e</b> (code $errorCode)"
                set pobj [::rwpage::RWBasicPage ::#auto $errorCode]
                set error_page $pobj

                dict for {k v} $opts {
                    append page_text "<pre><b>$k</b>: <pre>$v</pre>\n"
                }

                $pobj pagetext $::rivetweb::language $page_text "Error: $errorCode"
                set error_page $pobj
                set page       $pobj
            } finally {
                $this close_db_connection
            }
            return $page
        }
    }
}

package provide ngis::page 1.0
