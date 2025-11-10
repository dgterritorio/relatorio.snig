# -- sendmail.tcl
#
#

package require mime
package require smtp

namespace eval ::ngis::utils {

    variable msg_templates 

    array set msg_templates [list hash_changed {
    Message for MANAGER (EMAIL)
}]

    proc send_mail {template data_d} {
        variable msg_templates
        dict with data_d {
            if {[info exists email]   &&  \
                [info exists manager] &&  \
                [info exists hash]} {

                set msg [dict get $msg_templates $template]
                set msg [string map [list MANAGER       $manager    \
                                          EMAIL         $email      \
                                          SENDER_NAME   $::ngis::manager_name \
                                          SENDER_EMAIL  $::ngis::manager_email] $msg]




                return -code ok
            } else {
                return -code error -errorcode missing_template_argument "Missing argument to fill template"
            }
        }
    }

}
