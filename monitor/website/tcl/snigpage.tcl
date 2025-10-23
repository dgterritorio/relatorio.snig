#
# -- snig.tcl
#
# Site home page

package require rwpage
package require ngis::configuration
package require DIO
package require dio_Tdbc

namespace eval ::rwpage {

    ::itcl::class SnigPage {
        inherit RWPage

        private variable dbuser
        private variable dbhost
        private variable dbname
        private variable dbpasswd
        private variable dbms_driver

        private variable dbhandle


        constructor {key} {RWPage::constructor $key} {
            foreach v {dbuser dbhost dbname dbpasswd dbms_driver} {
                ::ngis::configuration readconf $v $v
            }
            set dbhandle ""
        }

        public method refresh {timereference} { return false }

        public method get_dbhandle {} {
            if {$dbhandle == "" } {
                set connectcmd  [list ::DIO::handle {*}$dbms_driver -user $dbuser -db $dbname -host $dbhost -pass $dbpasswd]
                set dbhandle    [eval $connectcmd]
            }
            return $dbhandle
        }

        public method close_dbhandle {} {
            $dbhandle destroy
            set dbhandle ""
        }

        public method js {} { }

        public method prepare_page {language argsqs} {
            $this title $language "[$this key]: [info object class $this]"
        }

        public method prepare {language argsqs} {
            RWPage::prepare $language $argsqs

            set page $this
            ::try {
                $this prepare_page $language $argsqs
            } on error {e opts} {

                if {[info command error_page] != ""} {
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
                #close_db_connection
            }
            return $page
        }
    }
}

package provide ngis::page 1.0
