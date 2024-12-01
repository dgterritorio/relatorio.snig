
set template_o [::rivetweb::RWTemplate::template monospace]

### debug
catch {::ngis::HRFormat destroy }
source ../tcloo/hrformat.tcl
::rivetweb::RWTemplate::read_formatters templates/monospace $template_o

namespace eval ::ngis {
    if {[string is true [::ngis::conf::readconf development]]} {
        set cssprogressive [clock seconds]
    }
}
