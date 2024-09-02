#
# -- snig.tcl
#
# Site home page

package require ngis::page
package require form

namespace eval ::rwpage {

    ::itcl::class SnigHome {
        inherit SnigPage

        private variable entities


        constructor {key} {SnigPage::constructor $key} { 
            set entities [dict create]
        }

        public method prepare_page {language argsqs} {
            if {[dict size $entities] == 0} {
                set dbhandle [$this get_dbhandle]
                ::ngis::conf readconf entities_table
                $dbhandle forall "SELECT * from $entities_table" e {
                    dict set entities $e(eid) $e(description)
                }
            }
        }

        public method print_content {language args} {

            ::rivet::parse rvt/entities.rvt


        }
    }
}

