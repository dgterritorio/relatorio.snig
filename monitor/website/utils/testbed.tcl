set auto_path [concat "/home/manghi/apache2/lib/rivet3" $auto_path]

package require DIO 1.2
package require dio_Tdbc 0.2

package require ngis::conf::generator
::ngis::conf init
package require ngis::configuration

source "/home/manghi/apache2/lib/rivet3/rivet-tcl/lempty.tcl"

::ngis::conf readconf dbuser
::ngis::conf readconf dbhost
::ngis::conf readconf dbname
::ngis::conf readconf dbpasswd
::ngis::conf readconf dbms_driver
::ngis::conf readconf entities_table

set connectcmd [list ::DIO::handle {*}$dbms_driver -user $dbuser -db $dbname -host $dbhost -pass $dbpasswd]
set ::dbms [eval $connectcmd]
