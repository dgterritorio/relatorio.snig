package require fileutil

source utils/testbed.tcl

source tcl/service_db.tcl
source tcloo/protocol.tcl
set proto_o [::ngis::Protocol new]
#set r [$proto_o resource_check_parser [list "Plano de Pormenor da Quinta da P%"] "services"]
set r [$proto_o resource_check_parser [list 2353] "services"]
set services [lindex $r 3]
set json [ngis::JsonFormat create json]

::ngis::service 

fileutil::writeFile /tmp/c116.json [$json c116 $services]
