package require ngis::conf
package require ngis::servicedb

set connector [::ngis::service get_connector]

set sql     "SELECT count(gid) as rcnt,record_entity from testsuite.uris_long ul"
lappend sql "left join testsuite.entities ent on ent.description=ul.record_entity"
lappend sql "where ent.eid is NULL group by record_entity"

set sql [join $sql " "]

set sql_res [::ngis::service exec_sql_query $sql]

set entities_l [$sql_res allrows -as dicts]

$sql_res close

set values_l {}
foreach e $entities_l {
    if {[dict exists $e record_entity]} {
        lappend values_l "('[dict get $e record_entity]')"
    }
}
set sql "INSERT INTO testsuite.entities (description) VALUES [join $values_l ","]"
puts $sql
#set sql_res [::ngis::service exec_sql_query $sql]
