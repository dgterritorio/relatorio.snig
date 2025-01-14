package require fileutil
set auto_path [concat "." $auto_path]
package require ngis::servicedb
set entities_l [lmap e [::ngis::service list_entities "%"] { lassign $e eid des cnt; list $eid "<a href=\"http://localhost:8080/index.rvt?entity=$eid\">$des</a>" $cnt}]
source website/templates/monospace/formatters.tcl
fileutil::writeFile /tmp/report.html [encoding convertfrom utf-8 "<pre>[entities_table $entities_l]</pre>"]
