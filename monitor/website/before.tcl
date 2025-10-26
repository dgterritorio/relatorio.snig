
if {[::ngis::configuration readconf development]} {
    set template_o [::rivetweb::RWTemplate::template monospace]

    ### debug

    catch {::ngis::HRFormat destroy }
    catch {::snig_nav_matrix destroy }
    catch {::snig_nav_bar destroy }

    source [file join [::ngis::configuration readconf snig_server_dir] tcloo hrformat.tcl]

    ::rivetweb::RWTemplate::read_formatters templates/monospace $template_o

    set template_o [::rivetweb::RWTemplate::template forty]
    ::rivetweb::RWTemplate::read_formatters templates/forty $template_o

}

namespace eval ::ngis {
    if {[string is true [::ngis::configuration readconf development]]} {
        set cssprogressive [clock seconds]
    }
    $::ngis::messagebox reset_message_queue
}
