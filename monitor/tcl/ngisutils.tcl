# -- sendmail.tcl
#
#

package require mime
package require smtp

namespace eval ::ngis::utils {

    variable msg_templates 

    array set msg_templates [list hash_changed {
    Message for MANAGER (EMAIL)

    SENDER_NAME
}]

    proc send_mail {template data_d} {
        variable msg_templates
        dict with data_d {
            if {[dict exists $msg_templates $template]} {
                set msg [dict get $msg_templates $template]
            } else {
                return -code error -errorcode invalid_message_template "Invalid message template '$template'"
            }

            switch $template {
                hash_changed {
                    if {[info exists email]   &&  \
                        [info exists manager] &&  \
                        [info exists hash]} {

                        set body [string map [list  MANAGER       $manager    \
                                                    EMAIL         $email      \
                                                    SENDER_NAME   $::ngis::manager_name \
                                                    SENDER_EMAIL  $::ngis::manager_email] $msg]

                        set token [mime::initialize -canonical "text/plain;charset=UTF-8" -string $body]
                        mime::setheader $token Subject "New URL for your data on the S.N.I.G monitoring system"
                        mime::setheader $token Reply-To "$manager <$email>"

                        ::ngis::msglogger emit "Sending mail to '$manager <$email>'"
                        #smtp::sendmessage $token -debug true -servers ....

                        return -code ok
                    } else {
                        return -code error -errorcode missing_template_argument "Missing argument to fill template"
                    }
                }
            }
        }
    }

}

package provide ngis::utils 1.0
