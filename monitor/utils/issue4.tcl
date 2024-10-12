#/usr/bin/tclsh8.6
#

set dot [lsearch $auto_path "."]
if {$dot < 0} {
    set auto_path [concat "." $auto_path]
} elseif {$dot > 0} {
    set auto_path [concat "." [lreplace $auto_path $dot $dot]]
}

package require ngis::conf
package require ngis::servicedb
package require ngis::task
package require ngis::job

::ngis::tasks build_tasks_database ./tasks

set dbms [::ngis::service get_connector]

set dbresults [::ngis::service exec_sql_query "select ul.gid,ul.uri from testsuite.uris_long ul where ul.uri like '%qgis_mapserv.fcgi?request=GetCapabilities&service=WFS&version=1.0.0%'"]


