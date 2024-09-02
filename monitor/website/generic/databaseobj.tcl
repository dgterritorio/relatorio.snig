# -- databaseobj.tcl
#
#   
#
package require Itcl
package require DIO

::itcl::class DatabaseObj {
    private variable columns
    public  variable primary ""
    public  variable key     ""
    private variable notnull ""
    private variable null    ""

    public variable table
    public variable armor   {}

    public variable attributes {} {
        foreach {c attr} $attributes {
            foreach a $attr {

                if {[lsearch $columns $c] >= 0} {
                    if {$a == "primary"}  { set primary $c }
                    if {$a == "key"}      { lappend key $c }
                    if {$a == "not_null"} { lappend notnull $c }
                    if {$a == "null"}     { lappend null $c }
                }

            }
        }
    }
    
    public method insert {dbhandle record_a}
    public method create {dbhandle record_a}
    public method store  {dbhandle record_a}
    public method delete {dbhandle record_a}
    public method fetch  {dbhandle record_l resrecord}
    public method update {dbhandle record_l} { 
        return [$this store $dbhandle $record_l]
    }
    public method search {dbhandle search_key}
    public method count {dbhandle {key ""}}

    protected method armor {field value} { 
        if { [lsearch $armor $field] >= 0 } {
            return [regsub {\s} $value {+}]
        } else {
            return $value 
        }
    }
    public  method keyfields {recnames}
    private method filter {record_l}
    private method notnull {columns}
    private method strip_null_values {database_rec}
    private method setnull {database_rec}
    public  method destroy {} { ::itcl::delete object $this }

    constructor {dbtable dbcolumns} {
        set table  $dbtable
        set columns $dbcolumns
    }
}

# -- search
#
#

::itcl::body DatabaseObj::search {dbhandle search_key} {
    set filtered [$this filter $search_key]
}

# -- count
#
#

::itcl::body DatabaseObj::count {dbhandle {key ""}} {

    if {$key == ""} {
        if {$primary == ""} {
            return -code error "table has no primary key"
        } else {
            set key $primary
        }
    } 
    
    return [$dbhandle count -table $table -keyfield $key]
}

# -- filter
#
# costruisce una lista dei campi validi all'interno del record
# saltando sia i campi non esistenti che i campi che sono chiavi
# primarie
#
# a list of valid columns is built by skipping those columns that
# are either primary keys or not existing in the columns list.
# The purpose of the method is to extract columns sets by stripping
# columns names unfit or wrong

::itcl::body DatabaseObj::filter {record_l} {
    array set record_a $record_l

    set filtered {}
    foreach f $columns {

        if {[info exists record_a($f)]} {
             lappend filtered $f $record_a($f)
        } else {
            continue
        }

    }
    return $filtered
}

# -- keyfields
#
# Il metodo cerca di creare comunque una chiave di ricerca
# per la tabella. 
#
#   - Se esiste un campo con l'attributo 'primary' il suo
#   valore viene ritornato come chiave
#   - Se ci sono campi definiti come chiave si cerca di
#   comporre la chiave sulla base delle variabili definite
#   nell'argomento record_l
#   - Se non ci sono campi chiave si cerca la chiave
#   nei campi definiti in record_l and nella lista delle
#   colonne della tabella.
#
#   Argomenti:
#
#       record_l: lista di coppie campo - valore
#
#   Valori ritornati:
#
#       lista dei campi componenti la chiave
#

::itcl::body DatabaseObj::keyfields {record_l} {

    array set record_a $record_l

    # prima di tutto verifichiamo se c'è una chiave primaria,
    # se esiste ritorniamo la sua definizione 

    if {($primary != "") && [info exists record_a($primary)]} { 
        return $primary 
    }
    if {[llength $key]} {
        set keycomplete 1
        foreach k $key {
            if {[info exists record_a($k)]} {
                continue
            } else {
                set keycomplete 0
                break
            }
        }
        if {$keycomplete} { return $key }
    }
    
    set filtered {}
    foreach f $columns {

        if {[info exists record_a($f)]} {
             lappend filtered $f 
        } else {
            continue
        }

    }
    return $filtered

}


# -- notnull 
#
#   Query a column to establish if it's not_null
#

::itcl::body DatabaseObj::notnull {fields} {

    foreach f $notnull {
        set notnull_present 1
        if {[lsearch $f $fields] < 0} {
            return -code error "missing not_null value"
        }
    }
    return -code ok

}

# -- setnull
#
#

::itcl::body DatabaseObj::setnull {database_rec} {
    upvar $database_rec dbrec

    foreach nv $null {
        if {[info exists dbrec($nv)] && ($dbrec($nv) == "")} {
            set dbrec($nv) "NULL"
        }
    }
}

::itcl::body DatabaseObj::create {dbhandle record_l} {

    foreach {f v} [$this filter $record_l] { set record_a($f) [$this armor $f $v] }
    #parray record_a
    $this notnull [array names record_a]
    set retvalue [$dbhandle insert $table record_a] 

    if {$retvalue == 1} {

        if {$primary == ""} {
            return 1
        } else {
            return [$dbhandle list "SELECT LAST_INSERT_ID();"] 
        }

    } else {

        # actually it should never get here

        return 0
    }

}

::itcl::body DatabaseObj::insert {dbhandle record_l} {
    foreach {f v} [$this filter $record_l] { set record_a($f) [$this armor $f $v] }
    set kf [$this keyfields $record_l]

    $this notnull [array names record_a]
    $this setnull record_a

    $dbhandle insert $table record_a
    return [$dbhandle list "SELECT LAST_INSERT_ID();"] 
}

::itcl::body DatabaseObj::store {dbhandle record_l} {
    foreach {f v} [$this filter $record_l] { set record_a($f) [$this armor $f $v] }
    set kf [$this keyfields $record_l]

    $this notnull [array names record_a]
    $this setnull record_a

    set cmd [list $dbhandle store record_a -table $table]
    if {[llength $kf] == 0} { set kf [array names record_a] } 
    lappend cmd -keyfield $kf

    return [eval $cmd]
}

::itcl::body DatabaseObj::delete {dbhandle record_l} {
    foreach {f v} [$this filter $record_l] { set record_a($f) [$this armor $f $v] }
    set kf [$this keyfields $record_l]

    if {[llength $kf] == 0} { return -code error "malformed delete query ($record_l)" }
    
    set recvals {}
    foreach v $kf { lappend recvals $record_a($v) }
    #::barbie::log "recvals -> $recvals"

    set cmd [list $dbhandle delete $recvals -table $table -keyfield $kf]
    #::barbie::log "-->$cmd"

    return [eval $cmd]
}

::itcl::body DatabaseObj::strip_null_values {database_rec} {
    upvar $database_rec dbrec

    foreach nv $null {
        if {[info exists dbrec($nv)] && ($dbrec($nv) == "")} {
            unset dbrec($nv)
        }
    }

}

::itcl::body DatabaseObj::fetch {dbhandle record_l resrecord} {
    upvar $resrecord results_a

    foreach {f v} [$this filter $record_l] { set record_a($f) $v }
    set kf [$this keyfields $record_l]

    set recvals ""
    set recvals [lmap v $kf {$this armor $v $record_a($v)}]

    set cmd [list $dbhandle fetch $recvals results_a -table $table]
    if {[llength $kf] == 0} { 
        lappend cmd -keyfield [array names record_a] 
    } else {
        lappend cmd -keyfield $kf
    }

    set return_value [eval $cmd]

    strip_null_values results_a

    return $return_value
}

package provide DatabaseTable 1.0
