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

        constructor {key} {RWPage::constructor $key} { }

        public method refresh {timereference} { return false }
        public method get_dbhandle {} { return $dbhandle }

        public method js {} { }

        public method prepare {language argsqs} {
            RWPage::prepare $language $argsqs

            ::try {
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
                #close_db_connection
            }
            return $page
        }
    }
}

package provide ngis::page 1.0
