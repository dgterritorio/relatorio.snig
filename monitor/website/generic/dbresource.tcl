#
# -- dbresource.tcl
#
# Abstract class for basic resource interface
#

package require Itcl
package require ngis::logger
package require ngis::configuration
package require safelock
package require DIO
package require uri

namespace eval ::ngis {

   ::itcl::class Resource {

        private common dbobj_cnts

        array set dbobj_cnts {}

        private variable fields
        private variable resource_table
        private variable primary_idx
        private variable ascii_key
        private variable null_key_on_insert

        # private methods

        private method eval_backend_proc {method dbms resource {res ""}}

        # protected methods

        protected method allow_null_key_on_insert {{b true}} { set null_key_on_insert $b }
        protected method delete_from_backend {dbms key} { return 0 }
        protected method delete_resource_row {dbms resource_id} 
        protected method insert_resource_row {dbms dbtable resource_a_var} 
        protected method insert_into_backend {dbms key resource}
        protected method update_backend {dbms key resource} 
        protected method publish_resource {dbms key publish} { return 0 }
        protected method extract_key {resource}
        public    method key_extracted {resource} { return [$this extract_key $resource] }
        public    method resource_exists {dbms key {residx resource_id}}
        public    proc   strip_punctuation {s} { return [regsub -all {[^[:alnum:]_]} $s ""] }
        public    proc   string_mangling {st} {
            #set st [regsub -all {[^\x20-\x7E]} $st "_"]
            #set st [string map [list "," "" ";" "" "'" "" "\\" "" "/" "" "." ""] $st]
            set st [string tolower [string range [regsub -all {[:\s]} $st "_"] 0 127]] 
            return [strip_punctuation $st]
        }
        protected proc quote {s} { return "'$s'" }
        #public   proc   string_unmangling {st} { return [regsub -all {_} $st " "] }

        protected method convert {resource} { return [dict create {*}$resource] }
        protected method serialize {resource} { return $resource }
        protected method normalize {resource} { return $resource }
        protected method fetch_row {dbms key}
        public    method table_name {} { return $resource_table }
        public    method primary_index {resource_d}
        protected proc   generate_key {res}
        protected method generate_random_key {res}

        # public interface

        public method insert {dbms resource} 
        public method update {dbms resource}
        public method fetch {dbms key}
        public method fast_fetch {dbms key}
        public method store {dbms resource {key ""}}
        public method delete {dbms key}
        public method publish {dbms key {publish y}}
        public method resource_fields {} { return $fields }
        public method destroy {} { ::itcl::delete object $this }
        public method validate_row {res_d} {
            return [dict filter $res_d key {*}$fields]
        }
        public method dump {res} { return $res }

        public method check {dbms key}
        public method set_ascii_key {key} { set ascii_key $key }
        public proc key_to_sql {key} {
            return [lmap {k v} $key { concat "$k=[quote $v]" }]
        }
        public proc is_void {res} { return [expr [dict size $res] == 0] }
        public proc is_defined {varname} {
            upvar $varname tcl_var

            if {[info exists tcl_var] && ($tcl_var != "")} {
                return 1
            } else {
                return 0
            }
        }

        public proc get_dbobj {class_name} {

            set class_name [namespace tail $class_name]

            if {[info exists dbobj_cnts($class_name)]} {
                set cnt [incr dbobj_cnts($class_name)]
            } else {
                set cnt 0
                set dbobj_cnts($class_name) $cnt
            }

            return "::ngis::[string tolower $class_name]${cnt}"
        }

        public method build_where_clause {key} {

            set conditions_l [lmap {k v} $key {
				if {[string is integer $v]} {
					concat "$k=$v"
				} else {
					concat "$k=[quote $v]"
				}
			}]

            return [join $conditions_l " AND "]
        }

        public method sql_fields {} {
            return "[$this table_name].*"
        }

        # inspecting how normalize method work in debugging sessions
        public method normform {resource} { return [$this normalize $resource] }

        constructor {table field_list} {

            # the following assignement of the fields member variable
            # is meant to remove multiple spaces in the field_list argument
            # in order to have clean list-like representation if this list
            # in case of debugging

            set fields              $field_list
            set primary_idx         [lindex $fields 0]
            set ascii_key           ""
            set resource_table      $table
            set null_key_on_insert  false
        }

    }

    ::itcl::body Resource::generate_key {res} { return [list] }

    ::itcl::body Resource::extract_key {resource} {
        if {[dict exists $resource $primary_idx]} {
            return [list $primary_idx [dict get $resource $primary_idx]]
        } else {
            return [list]
        }
    }

    ::itcl::body Resource::eval_backend_proc {method dbms key {resource ""}} {
        #::ngis::log "evaluating: $this $method $dbms $key $resource" debug
        if { $resource != "" } {
            return [$this $method $dbms $key $resource]
        } else {
            return [$this $method $dbms $key]
        }
    }

    # -- update_backend
    #
    # this method actually updates a record assuming the
    # resource record has already been normalized and tested
    # for existence

    ::itcl::body Resource::update_backend {dbms key res_normal} {
        ::ngis::log "update $resource_table with key >$key<" debug

        #set current_resource [$this fetch $dbms $key]
        #if {![dict exists $current_resource $primary_idx]} {
        #    return 0
        #}

        #set idx [$this primary_index $current_resource]
        #if {$idx == 0} {
        #    return -code error -errorcode resource_not_found "Resource for key $key not existing"
        #}

		# the merge of the normalized resource representation (res_normal) with the key is not
		# needed in most cases but we keep open the possibility of creating keys from representations
		# like for the page object

        array set resource_a [$this validate_row [dict merge $res_normal $key]]

        #set resource_a($primary_idx) $idx
        #parray resource_a


        $dbms update resource_a -table $resource_table -keyfield [dict keys $key]
		
        # for sake of reproducibility we return the primary index but we
        # could return since update returns invariably 1
        
        set keyfield [dict keys $key]
        if {[$dbms fetch [$dbms makekey resource_a $keyfield] resource_a -table [$this table_name] -keyfield $keyfield]} {
            return $resource_a($primary_idx)
        } else {
            return 0
        }
    }

    ::itcl::body Resource::primary_index {resource_d} {
        if {[dict exists $resource_d $primary_idx]} {
            return [dict get $resource_d $primary_idx]
        } else {
            return 0
        }
    }

    ::itcl::body Resource::insert_into_backend {dbms key res_normal} {
        ::ngis::log "eval insert with key >$key< in $resource_table" debug
        ::ngis::log "inserting >$res_normal< with key >$key< in $resource_table" debug

        set record_d [$this validate_row [dict merge $res_normal $key]]

        array set resource_a $record_d
        #parray resource_a

        # we are inserting, assigning a value to the resource primary id is a DBMS duty

        if {[info exists resource_a($primary_idx)]} { unset resource_a($primary_idx) }

        ::safelock::prepare_safelock

		# locking the table is necessary: we must be sure the last_inserted_id call
		# is referred to this record.

        ::safelock::runsafelock $dbms ${resource_table}:w {
            set idx [$this insert_resource_row $dbms $resource_table resource_a]
        }
        return $idx
    }

    ::itcl::body Resource::insert_resource_row {dbms dbtable resource_a_var} {
        upvar $resource_a_var resource_a

        ::safelock::assert_safelock [list ${dbtable}:w]

        set cmd [list $dbms insert $dbtable resource_a]
        ::ngis::log "eval >$cmd<" debug
        if {[eval $cmd]} {
            set resourceid [$dbms list "SELECT LAST_INSERT_ID();"] 
        } else {
            set resourceid 0
        }

        return $resourceid
    }

    ::itcl::body Resource::delete_resource_row {dbms resource_id} {
        return [$dbms delete $resource_id -table $resource_table -keyfield $primary_idx]
    }

    ::itcl::body Resource::fetch_row {dbms key} {
        if {[dict size $key]} {
            foreach {k v} $key {
                lappend keyv $v
                lappend keyf $k
            }

            ::ngis::log "fetching row from '$resource_table' (key: $key)" debug

            set r [$dbms fetch $keyv resource_a -table $resource_table -keyfield $keyf]
            set resource_d [dict create {*}[array get resource_a]]

            return $resource_d
        } else {
            return [dict create]
        }
    }

    ::itcl::body Resource::fetch {dbms key} {
        set key [$this extract_key $key]
        if {$key == ""} { return "" }
        return [$this fetch_row $dbms $key]
    }

    ::itcl::body Resource::resource_exists {dbms key {residx resource_id}} {
        upvar 1 $residx res_primary_idx

        set res [$this fetch_row $dbms $key]
        if {[dict size $res]} {
            set res_primary_idx [$this primary_index $res]
            return true
        } else {
            set res_primary_idx ""
            return false
        }
    }

    ::itcl::body Resource::delete {dbms resource} {
        if {[dict exists $resource $primary_idx]} {
            return [$this delete_resource_row $dbms [dict get $resource $primary_idx]]
        } else {
            set key [$this extract_key $resource]
            if {[llength $key] > 0} {
                ::ngis::log "deleting resource with key: '$key' extracted from: $resource" debug
                return [$this eval_backend_proc delete_from_backend $dbms $key]
            } else {
                return 0
            }
        }
    }

    ::itcl::body Resource::check {dbms key} {
        if {$key == ""} { return false }

        return [$this eval_backend_proc resource_exists $dbms $key]
    }

    ::itcl::body Resource::generate_random_key {res} { return "" }

    ::itcl::body Resource::insert {dbms resource} {
        set resource [$this normalize $resource]
        set key      [$this extract_key $resource]
        ::ngis::log "key: '$key' extracted from: $resource" debug
        if {[llength $key] == 0} { set key [generate_key $resource] }
        ::ngis::log "actual key: $key" debug
        if {[llength $key] > 0} {
            if {[$this resource_exists $dbms $key]} {
                return -errorcode resource_exists -code error "Resource exists for key: $key"
            }
            return [$this eval_backend_proc insert_into_backend $dbms $key $resource]
        } else {

            if {$null_key_on_insert} {
                return [$this eval_backend_proc insert_into_backend $dbms $key $resource]
            }

            return -code error -errorcode missing_key "Couldn't insert row in table (no key defined)"
        }
    }

    ::itcl::body Resource::update {dbms resource} {
        set resource [$this normalize $resource]
        set key      [$this extract_key $resource]
        if {[llength $key]} {
            if {[$this resource_exists $dbms $key]} {
                return [$this eval_backend_proc update_backend $dbms $key $resource]
            } else {
                ::ngis::log "Couldn't update resource for key $key. Resource missing" err
                return -code      error \
                       -errorcode resource_missing "Couldn't update resource for key $key. Resource missing"
            }
        }
        return 0
    }

    ::itcl::body Resource::publish {dbms key {publish y}} {
        return [$this eval_backend_proc publish_resource $dbms $key $publish]
    }

    # -- store
    #
    # unified method for storing a resource in the database
    # From the representation 'resource' a key is generated
    # and if a resource for that key value exists method update
    # is called
    #

    ::itcl::body Resource::store {dbms resource {key ""}} {
        set resource [$this normalize $resource]
        if {$key == ""} { set key [$this extract_key $resource] }

        if {$key != ""} {

            if {[$this resource_exists $dbms $key]} {
                return [$this eval_backend_proc update_backend $dbms $key $resource]
                #return [$this update $dbms $resource]
            } else {
                return [$this insert $dbms $resource]
            }

        }
        return 0
    }

    # -- fast_fetch
    #
    #

    ::itcl::body Resource::fast_fetch {dbms key} {
        if {[string is integer $key]} {
            return [$this fetch $dbms [list $primary_idx $key]]
        } elseif {$ascii_key != ""} {
            return [$this fetch $dbms [list $ascii_key $key]]
        } 
        return ""
    }

    ::itcl::class Entity {
        inherit Resource

        constructor {table_name} \
                    {Resource::constructor $table_name {eid description}} {

        }

        public proc mkobj {} {
            ::ngis::conf readconf entities_table

            return [::ngis::Entity [::ngis::Resource::get_dbobj "Entity"] $entities_table]
        }

    }

}
package provide ngis::dbresource 1.0
