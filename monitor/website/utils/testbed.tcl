set auto_path [concat "/home/manghi/apache2/lib/rivet3" $auto_path]
set dot [lsearch "." $auto_path]
if {$dot < 0} {
    set auto_path [concat "." $auto_path]
} elseif {$dot > 0} {
    set auto_path [concat "." [lreplace $auto_path $dot $dot]]
}

package require ngis::configuration
package require DIO 
package require dio_Tdbc

source "/usr/lib/tcltk/rivet3/rivet-tcl/lempty.tcl"

::ngis::configuration readconf dbuser
::ngis::configuration readconf dbhost
::ngis::configuration readconf dbname
::ngis::configuration readconf dbpasswd
::ngis::configuration readconf dbms_driver
::ngis::configuration readconf entities_table

set connectcmd [list ::DIO::handle {*}$dbms_driver -user $dbuser -db $dbname -host $dbhost -pass $dbpasswd]
set ::dbms [eval $connectcmd]
