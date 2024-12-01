#
# -- snig.tcl
#
# Site home page

package require rwpage
package require ngis::configuration

namespace eval ::rwpage {

    ::itcl::class SnigPage {
        inherit RWPage

        private variable dbhandle

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
            set dbhandle    ""
            set dbms_driver [::ngis::conf::readconf dbms_driver]
        }

        public method refresh {timereference} { return false }
        public method get_dbhandle {} { return $dbhandle }

        private method attempt_db_connect {} {
            if {$dbhandle == ""} {
                set connectcmd [list ::DIO::handle {*}$dbms_driver -user $dbuser -db $dbname -host $dbhost -pass $dbpasswd]
                set ::dbms [eval $connectcmd]
                set dbhandle $::dbms
            }
            return $dbhandle
        }

        private method close_db_connection {} {
            if {$dbhandle != ""} { 
                $dbhandle destroy
                set dbhandle ""
            }
        }

        public method js {} { }

        public method prepare {language argsqs} {
            RWPage::prepare $language $argsqs

            ::try {
                $this attempt_db_connect

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
