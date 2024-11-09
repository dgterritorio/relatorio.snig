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
            set entities [list]
        }

        public method prepare_page {language argsqs} {
            if {[dict size $entities] == 0} {
                set dbhandle [$this get_dbhandle]
                ::ngis::conf readconf entities_table
                ::ngis::conf readconf uris_table

                set    sql "SELECT e.eid eid,e.description description,count(ul.gid) as cnt from $entities_table e"
                append sql " LEFT JOIN $uris_table ul ON ul.eid=e.eid group by e.eid order by cnt desc"
                puts $sql
                #$dbhandle forall "SELECT * from $entities_table" e
                $dbhandle forall $sql e {
                    if {$e(cnt) > 0} {
                        lappend entities [list $e(eid) $e(description)]
                    }
                }
            }
        }

        public method print_content {language args} {
            ::rivet::parse rvt/entities.rvt
        }
    }
}

