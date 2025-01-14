# snigutils.tcl --
#
# As usual, some place must be found where tools and stuff that don't fit anywhere else
# can be placed
#

package require ngis::servicedb

namespace eval ::ngis::utils {

    # tbreakdown --
    #
    # accepts a delta time in seconds and returns a 4-element list
    # forming a breakdown of the time showing explicitly (when relevant)
    #
    #   - days
    #   - hours
    #   - mins
    #   - secs (always displayed)

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

    # delta_time_s --
    #
    # 

    proc delta_time_s {t} {

        lassign [tbreakdown $t] days hours mins secs

        if {$days > 0} {
            return [format "%d days, %d hours, %d mins, %d secs" $days $hours $mins $secs]
        } elseif {$hours > 0} {
            return [format "%d hours, %d mins, %d secs" $hours $mins $secs]
        } elseif {$mins > 0} {
            return [format "%d mins, %d secs" $mins $secs]
        } else {
            return [format "%d secs" $secs]
        }
    }

    # string_truncate --
    #
    # if the string 'a_string' length is < $string_max the string is returned.
    # Otherwise the the last occurrence of a space/newline before the characted
    # with index '$string_max-3' is searched and the string is padded with an ellipsis
    # In case it's a long string without spaces 3 characters of the string are chopped
    # away and replaced with an ellipsis
    #

    proc string_truncate {a_string string_max} {
        set slen [string length $a_string]

        if {$slen < $string_max} { return $a_string }

        # we procede by subtraction. We split the string
        # is a list and remove element until we reached the
        # length of string_max-3

        set a_list [lreverse [split $a_string " "]]
        set target_len [expr $string_max - 3]

        # for every word we actually are removing [string length $word] + 1 characters

        set cnt 0
        set word ""
        set removed_len 0
        while {([expr $slen - $removed_len - 1] > $target_len) && ([incr cnt] < 20)} {
            set a_list [lassign $a_list word]
            set removed_len [expr $removed_len + [string length $word]]
            #puts "$a_list ($removed_len)"
        }

        # without spaces we end up consuming all elements in a_list

        if {[llength $a_list] == 0} {
            return "[string range $a_string 0 $string_max-4]..."
        } else {
            return "[join [lreverse $a_list] " "]..."
        }
    }

    # resource_check_parser (and loader, see below)
    #
    # parses the arguments of command CHECK and builds job sequences
    # to be thrown to the job_controller
    #
    # forms to be detected are:
    #
    #   1. pure integer: gid of a resource rec in uris_long
    #   2. gid=<int>: synonimous of the former
    #   3. eid=<int>: integer primary key to an entity.
    #   4. pure text: entity or record definition.
    #
    # TODO: This procedure is badly designed and needs reform.
    # It combines argument parsing and value estration to real
    # data retrieval for two classes of information, entities and
    # URL services records (table uris_long). Such hybrid behavior
    # is a temporary solution and needs cleaner design
    #

    proc resource_check_parser {arguments {class entities}} {
        set gids_l {}
        set eids_l {}
        set resources_l {}
        set retstatus OK
        foreach a $arguments {
            #set a [string tolower $a]

            if {[string is integer $a] && ($a > 0)} {
                lappend gids_l $a
            } elseif {[regexp {(eid|gid)=(\d+)} $a m type primary_id] && \
                      [string is integer $primary_id] && ($primary_id > 0)} {

                if {$type == "eid"} {
                    lappend eids_l $primary_id
                } elseif {$type == "gid"} {
                    lappend gids_l $primary_id
                }

            } else {
                switch $class {
                    entities {
                        # ::ngis::service list_entities returns a list of 3-element descriptors
                        # (as a matter of fact a record in the entities table with columsn stripped of the keys)
                        lappend resources_l {*}[::ngis::service list_entities $a]
                    }
                    services {
                        # ::ngis::service list_servicces returns 
                        lappend resources_l {*}[::ngis::service service_data $a]
                    }
                }
            }
        }

        if {([llength $gids_l] == 0) && ([llength $eids_l] == 0) && \
            ([llength $resources_l] == 0)} {
            return [list ERR "109" "No valid records found"]
        }
        return [list $retstatus $gids_l $eids_l $resources_l]
    }
}

package provide ngis::utils 0.3
