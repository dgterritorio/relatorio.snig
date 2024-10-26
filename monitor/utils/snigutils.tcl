# snigutils.tcl --
#
# As usual, some place must be found where tools and stuff that don't fit anywhere else
# can be placed
#


namespace eval ::ngis::utils {

    # tbreakdown --
    #
    # accepts a delta time in seconds
    # and returns a 4-element list
    # forming a breakdown of the time
    # 
    #   - days
    #   - hours
    #   - mins
    #   - secs

    proc tbreakdown {t} {
        set days  0
        set hours 0
        set mins  0
        set secs  0

        set days [expr int($t / (3600*24))]
        set t [expr $t - $days * 3600 * 24]

        set hours [expr int($t / 3600)]
        set t [expr $t - $hours * 3600]

        set mins [expr int($t / 60)]
        set secs [expr $t - 60 * $mins]

        return [list $days $hours $mins $secs]
    }

    proc delta_time_s {t} {

        lassign [tbreakdown $t] days hours mins secs

        if {$days > 0} {
            return [format "%d days, %d hours, %d mins, %d secs" $days $hours $mins $secs]
        } elseif {$hours > 0} {
            return [format "%%d hours, %d mins, %d secs" $hours $mins $secs]
        } else {
            return [format "%d mins, %d secs" $mins $secs]
        }
    }

}

package provide ngis::utils 0.1
