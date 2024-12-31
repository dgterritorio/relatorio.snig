# -- request_handler.tcl
#
# Copyright 2002-2017 The Apache Rivet Team
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# code of the default handler of HTTP requests

    ::try {
        ::Rivet::initialize_request
    } on error {err} {
        ::rivet::apache_log_error crit \
            "Rivet request initialization failed: $::errorInfo"
    }

    ::try {

        set session_obj [::rwdatas::NGIS::get_session_obj]

        $session_obj activate
        set newsession [$session_obj is_new_session]
        if {$newsession} {
            if {$::ngis::debugging} {
                $session_obj store status logged    1
                $session_obj stash login  [dict create user "snig-dev"]
            } else {
                $session_obj store status logged    0
            }
        }

        if {[::rivet::var_qs exists login]} {

            # this should simply send to the login form
            # a development installation automatically logs in
            # as administrative user

            if {$development  && ![::rivet::var_qs exists ignoredev]} {
                $session_obj store status logged  1
                $session_obj stash login  $admin_d
                ::rivet::redirect [::rivetweb::composeUrl display umr5229]
            } else {
                set key snig_login
                return -code break -errorcode rw_ok
            }

        } else {

            if {[::rwdatas::NGIS::is_logged] && [::rivet::var_qs exists logout]} {

                $session_obj store status logged        0

                $session_obj clear login
                $session_obj store login  memberid      0
                $session_obj store login  admin         0

                ::rivet::redirect [::rivetweb::composeUrl]

            }
        }

        eval $::rivetweb::handler_script
    } trap {RIVET ABORTPAGE} {err opts} {
        ::Rivet::finish_request $::rivetweb::handler_script $err $opts AbortScript
    } trap {RIVET THREAD_EXIT} {err opts} {
        ::Rivet::finish_request $::rivetweb::handler_script $err $opts AbortScript
    } on error {err opts} {
        ::Rivet::finish_request $::rivetweb::handler_script $err $opts
    } finally {
        ::Rivet::finish_request $::rivetweb::handler_script "" "" AfterEveryScript
    }
   
# default_request_handler.tcl ---
