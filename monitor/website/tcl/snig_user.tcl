package require ngis::page

namespace eval ::rwpage {

    ::itcl::class SnigUser {
        inherit SnigPage

        private variable rvt_template
        private variable form_defaults
        private variable post_url
        private variable button_label

        constructor {key} {SnigPage::constructor $key} {
            array set form_defaults {}
        }

        public method prepare_page {language argsqs} {
            array unset form_defaults
            set dbhandle [$this get_dbhandle]
            set rvt_template ""
            set button_label "Create"
            set usertable [::ngis::configuration readconf users_table]

            set session_obj      [::rwdatas::NGIS::get_session_obj]
            set current_login    [$session_obj fetch status login]

            #puts "<pre>current login: $current_login</pre>"

            set is_administrator [::rwdatas::NGIS::is_administrator $current_login]

            if {[dict exists $argsqs newuser]} {

                if {!$is_administrator} {
                    $ngis::messagebox post_message "Function requires administrative privileges" error
                    $this title $language "Error: insufficient administrative privileges"
                    return
                }

                $this title $language "Create New User"
                set rvt_template newuser.rvt
                set post_url    [::rivetweb::composeUrl createuser 1]

            } elseif {[dict exists $argsqs updateuser]} {

                set userid      [dict get $argsqs updateuser]
                set login       [string trim [::rivet::var_post get login]]
                set password    [string trim [::rivet::var_post get password]]

                if {[$dbhandle fetch $current_login userrec -table $usertable -keyfield {login}]} {
                    if {($userrec(userid) == $userid) || $is_administrator} {

                        set sql "UPDATE $usertable SET (login,password) = ('$login',crypt('$password',gen_salt('bf'))) WHERE userid=$userrec(userid)"
                        set sqlres [$dbhandle exec $sql]
                        $sqlres destroy

                        set message_t "Update login '$login' done"
                        $ngis::messagebox post_message $message_t
                        $this title $language $message_t

                    } else {

                        $ngis::messagebox post_message "Function requires administrative privileges" error
                        $this title $language "Error: insufficient administrative privileges"
                        return

                    }
                }

            } elseif {[dict exists $argsqs createuser]} {

                if {!$is_administrator} {
                    $ngis::messagebox post_message "Function requires administrative privileges" error
                    $this title $language "Error: insufficient administrative privileges"
                    return
                }
                set login       [string trim [::rivet::var_post get login]]
                set password    [string trim [::rivet::var_post get password]]

                # in case of error we redirect to the create user form

                set post_url    [::rivetweb::composeUrl createuser 1]
                set form_defaults(login) $login
                set button_label "Create"
                if {[string length $login] < 5} {
                    $ngis::messagebox post_message "Invalid login (login must be at least 5 characters long)"
                    set rvt_template newuser.rvt
                }
                if {[regexp -nocase {^[a-z][a-z0-9_]{7,}} $password] == 0} {
                    $ngis::messagebox post_message "Invalid password '$password': must be at least 8 characters" error
                    $this title $language "Error: insufficient administrative privileges" 
                    set rvt_template newuser.rvt
                }

                # not very elegant: we are using the rvt template name
                # as variable to handle also the result status

                if {$rvt_template == ""} {

                    # if rvt_template is empty we attempt to store the data

                    if {[llength [$dbhandle list "SELECT su.userid FROM $usertable su WHERE su.login='$login'"]] > 0} {
                        $ngis::messagebox post_message "login '$login' already existing" error
                        set rvt_template newuser.rvt
                        return
                    } else {

                        set sql     [list "INSERT INTO $usertable (login,password,ts)"]
                        lappend sql "VALUES ('$login',crypt('$password',gen_salt('bf')),clock_timestamp())"
                        set sql [join $sql " "]

                        #puts [::rivet::xml $sql pre]
                        set sqlres [$dbhandle exec $sql]
                        $sqlres destroy
                        set userid [$dbhandle list "SELECT su.userid FROM $usertable su WHERE su.login='$login'"]
                        if {$userid != ""} {
                            set msg "new login '$login' created with userid '$userid'"
                            set severity info
                        } else {
                            set msg "error creating login '$login'"
                            set serverity error
                        }
                        $ngis::messagebox post_message "new login '$login' created with userid '$userid'" $severity
                        $this title $language "New user '$login' created"

                    }
                }

            } elseif {[dict exists $argsqs edituser]} {

                set userid   [dict get $argsqs edituser] 
                set post_url [::rivetweb::composeUrl updateuser $userid]

                if {[$dbhandle fetch $userid form_defaults -table $usertable -keyfield {userid}]} {
                    if {($form_defaults(login) == $current_login) || $is_administrator} {
                        unset form_defaults(password)
                        $ngis::messagebox post_message "edit login '$form_defaults(login)' (userid '$userid')"
                        $this title $language "login '$form_defaults(login)' (userid '$userid')"
                        set rvt_template newuser.rvt
                        set button_label "Update"
                    } else {
                        $ngis::messagebox post_message "Function requires administrative privileges" error
                        $this title $language "Error: insufficient administrative privileges"
                        return
                    }
                } else {
                    $ngis::messagebox post_message "invalid userid: $form_defaults(userid)" error
                }

            } elseif {[dict exists $argsqs deleteuser]} {

                if {!$is_administrator} {
                    $ngis::messagebox post_message "Function requires administrative privileges"
                    return
                }

                set userid [dict get $argsqs deleteuser]
                set nusers [$dbhandle list "SELECT count(userid) FROM $usertable"]

                # assuming user 'dgt' has userid = 1
                set severity error
                set msg ""
                if { $nusers == 1 } {
                    set msg  "Can't delete the user: last user remaining"
                } elseif { $userid == 1 } {
                    set msg "Can't delete the basic administrative user"
                } elseif {[$dbhandle fetch $userid userrec -table $usertable -keyfield {userid}]} {
                    $dbhandle delete $userid -table $usertable -keyfield {userid}
                    set msg "Login '$userrec(login)' with id '$userrec(userid)' deleted"
                    set severity info
                }
                $ngis::messagebox post_message $msg $severity
                $this title $language $msg
            }
        }

        public method print_content {language} {
            if {$rvt_template != ""} { 
                ::rivet::parse [file join rvt $rvt_template]
            }
        }

    }
}




