# storing here http releated example procedures

package require http
package require uri
package require tls

http::register https 443 [list ::tls::socket -tls1 true]

    # --

proc get_url {job} {
    incr ::job_counter

    set jobname  [dict get $job jobname]
    set url      [dict get $job url]

    if {[catch {

        emit "getting $url"
        #::http::geturl $url -command url_cb
        set tk [::http::geturl $url]
        set http_returned_data [::http::data $tk]
        emit "$jobname: got [string length $http_returned_data] bytes from $url"

    } e einfo]} {
        return [list $jobname error $e $einfo ""]
    }
    return [list $jobname ok "" "" $http_returned_data]
}

