#
# trimmer.tcl
#
# Classes for generalizing plain and HTML text manipulation
# to compose reports in different contexts

::oo::class create ::ngis::HTMLTrimmer {

    method HTMLElementBreakdown {str element_text_v open_tag_v close_tag_v} {
        upvar 1 $element_text_v element_text
        upvar 1 $open_tag_v open_tag
        upvar 1 $close_tag_v close_tag

        set matched [regexp {(<\w+\s*.*>)(.*)(</\w+>)} $str -> open_tag element_text close_tag]
        if {!$matched} {
            set element_text $str 
            set open_tag     ""
            set close_tag    ""
        }
        return $matched
    }

    method ExtractElementText {str} {
        my HTMLElementBreakdown $str etext open_tag close_tag
        return $etext
    }

    method StringLength {str} {
        HTMLElementBreakdown $str element_text tag_o tag_c
        return [string length $element_text]
    }

    method trim {str {limit 80}} {
        set matched [HTMLElementBreakdown $str element_text tag_o tag_c]
        if {$element_text > $limit} {
            return "${open_tag}[string range $etext 0 [expr $limit - 4]]...${close_tag}"
        } 
        return $str
    }
}

package provide ngis::trimmers 0.1
