#
# -- configuration.tcl
#
# 

package require ngis::logger
package provide ngis::conf::generator 1.0

namespace eval ::ngis::conf {
    variable sections
    variable currentdefs     [file join . ngis_conf.tcl]
    variable currentdefs_sh  [file join . ngis_conf.sh]
    variable confnamespace   ngis::conf
    variable section_order   [list snig_server website dbauth database network jquery]
    variable dbconfiguration \
        [list   website         {value "http://snig.rivetweb.org:8080" description "Website Name" section website} \
                encoding        {value "utf-8" description "Website default character encoding" section website } \
                cssprogressive  {value "20241201" description "CSS progressive number to force reloads" section website} \
                service_recs_limit {value 100 description "Size of the default view of an entity service records" section website } \
                development     {value "true" description "Flag to enable development site specific parts" section website} \
                dbuser          {value "dgt" description "Backend database user" section dbauth } \
                dbname          {value "snig" description "Backend database" section dbauth } \
                dbhost          {value "snig.naturalgis.pt" description "Backend database host" section dbauth} \
                dbpasswd        {value "W8a1kCUOx0mupUAF" description "DB password" section dbauth} \
                dbport          {value "5432" description "Backend database port" section dbauth} \
                service_status  {value "testsuite.service_status" description "Service Status Records" section database} \
                entities_table  {value "testsuite.entities" description "Entities catalog table" section database} \
                uris_table      {value "testsuite.uris_long" description "URIs catalog table" section database} \
                users_table     {value "testsuite.snig_users" description "SNIG User Table" section database} \
                dbms_driver     {value "Tdbc Postgresql" description "Database DIO Driver" section database} \
                jquery_uri      {value "/jQuery/jquery.min.js" description "jQuery file name" section jquery } \
                server_ip       {value "127.0.0.1" description "SNIG Monitor Server" section network} \
                server_port     {value "4422" description "SNIG Monitor Server Port" section network} \
                snig_server_dir {value ".." description "SNIG Monitor Server Root Directory" section snig_server}
        ]

    proc sections {{s ""}} {
        variable sections

        if {$s == ""} {
            return [lsort [dict keys $sections]]
        } else {
            return [lsort [dict get $sections $s]]
        }

    }
    namespace export sections

    # -- parameters
    #
    # Canonical method to read the configuration parameters list
    #

    proc parameters {args} {
        variable dbconfiguration

        if {[llength $args] == 0} {
            return [lsort [dict keys $dbconfiguration]]
        } else {
            return [dict get $dbconfiguration {*}$args]
        }

    }
    namespace export parameters

    # -- readconf
    #
    # funzione di accesso semplice al valore di configurazione
    # di un parametro.
    # 
    # Argomenti:
    #
    #   - confpar:      nome della variabile per il valore del 
    #                   parametro di configurazione. Se il secondo
    #                   argomento non è speficicato allora il 
    #                   parametro di configurazione è il nome
    #                   di questa variabile
    #   - confparvar:   nome della variabile dove scrivere la risposta
    #                   
    # Effetti:
    #       nessuno
    #

    proc readconf {confpar {confparvar ""}} {

        if {$confparvar != ""} { 
            upvar $confparvar v 
        } else {
            upvar $confpar v
        }

        set v [parameters $confpar value]

        return $v
    }
    namespace export readconf

    # -- quote_string
    #
    #

    proc quote_string {s} {
        if {[string is entier $s] ||\
            [string is double $s]} {
            return $s
        } else {
            return "\"$s\""
        }
    }


    # -- generate
    #
    # 

    proc generate {configscript} {
        variable section_order
        variable confnamespace

        #puts "section_order: $section_order"
        #puts "sections: [sections]"

        set sections_filtered [lmap s [sections] {
            if {$s == "removed"} {
                continue
            }
            set s
        }]

        if {[llength $section_order] != [llength $sections_filtered]} {
            return -code error -error_code section_mismatch \
                    "Section number mismatch in configuration ([llength $section_order] vs [llength $sections_filtered])"
        }

        set confts [clock format [clock seconds] -format "%d-%m-%Y %T"]

        set distribution_vars [parameters]
        set source_vars $distribution_vars

        # inizializziamo un namespace vuoto per le definizioni

        namespace eval $confnamespace {}
        if {[file exists $configscript]} {
            source $configscript
        }

        set newconf   [open $configscript w]
        puts $newconf "#\n# -- $configscript\n#"
        puts $newconf "#\n# Configuration file regenerated $confts \n#\n"
        puts $newconf "package require ngis::conf::generator"
        puts $newconf "namespace eval $confnamespace {"

        foreach sect $section_order {
            puts $newconf "\n\# -- Section $sect\n#"
            foreach parm [sections $sect] {
                if {[info exists ${confnamespace}::$parm]} {
                    set value [set ${confnamespace}::${parm}]
                } else {
                    set value [parameters $parm value]
                    ::ngis::log "add missing variable '$parm', initial value = $value" notice
                }
                puts $newconf [format "\tvariable %-24s %-40s ;# %s" $parm [quote_string $value] [parameters $parm description]]
            }
        }
        puts $newconf "\n}"
        puts $newconf "package provide ngis::configuration 1.1"

        close $newconf
    }
    namespace export generate

    # -- build_database
    #
    # private method to build the dictionary based inner 
    # representation of the database. We are not exporting 
    # build_database and should be kept private
    #

    proc sections_database {} {
        variable dbconfiguration
        variable sections

        ngis::log     "initializing sections database" info
        set sections  [dict create]

        dict for {parameter conf_value} $dbconfiguration {
            dict lappend sections [dict get $conf_value section] $parameter
        }
    }

    # -- merge
    #
    # legge la configurazione e ne fa il merge con
    # il database interno. Si assume che il file di configurazione
    # sia già stato allineato, quindi questa procedura non
    # viene esportata perché deve essere usato secondo la logica 
    # interna a questo package
    #

    proc merge {configscript} {
        variable dbconfiguration
        variable confnamespace

        set csfp [open $configscript r]
        set current_conf_tcl [read $csfp]
        close $csfp
    
        #source $configscript

        eval $current_conf_tcl

        # construiamo un database di parametri e commenti

        set currentdefs_db [dict create]
        foreach line [split $current_conf_tcl "\n"] {

            # rimpiazziamo spazi multipli con uno solo e poi splittiamo
            # in una lista

            set line [string trim $line]

            set line_l [split [regsub -all {\s+} $line " "] " "]

            #puts $line_l
            if {[lindex $line_l 0] == "variable"} {
                dict set currentdefs_db [lindex $line_l 1] \
                                        [string trim [lindex [split $line "#"] end]]
            }
        }

        set force_generation 0
        foreach parm [parameters] {
            if {[info exists ${confnamespace}::${parm}]} {

                dict set dbconfiguration $parm value [set ${confnamespace}::${parm}]

            } else {
                
                # se questa variabile non esiste in ::ngis::conf
                # allora è stata rimossa dal database e quindi segnaliamo
                # di forzare la generazione dei file di configurazione

                set force_generation 1
            }
        }

        # ciclo inverso: andiamo a memorizzare nel database le variabili rimosse
        # con il loro valore

        foreach confvar [info vars ${confnamespace}::*] {
            set v [namespace tail $confvar]
            if {![dict exists $dbconfiguration $v]} {

                # deve esistere una descrizione

                set desc [dict get $currentdefs_db $v]

                dict set dbconfiguration $v \
                        [dict create section removed value [set $confvar] description $desc]
            }
        }
        return $force_generation
    }

    proc generate_sh {config_sh} {

        set shfp [open $config_sh w+]
        foreach sect [sections] {
            puts $shfp "\n\# -- Section $sect\n#"
            foreach parm [sections $sect] {
            
                set value [parameters $parm value]
                puts $shfp "$parm=\"$value\"\t# [parameters $parm description]"

            }
        }
        close $shfp
    }


    proc init {{force_align 0}} {
        variable currentdefs
        variable currentdefs_sh
        variable sections

        ngis::log "generating the conf sections database" info
        sections_database

        # deteterminiamo se la configurazione va rigenerata
        #
        #    - se $currentdefs non esiste
        #    - se $currentdefs_sh non esiste
        #    - se la [mtime $currentdefs_sh] < [mtime $currentdefs] 
        #

        set tcldefs_f [file exists $currentdefs]
        set shdefs_f  [file exists $currentdefs_sh]

        set conf_changed $force_align
        if {$tcldefs_f && $shdefs_f} {
            file stat $currentdefs      tcldefs
            file stat $currentdefs_sh   shdefs

            if {$tcldefs(mtime) > $shdefs(mtime)} {
                set conf_changed 1
            }
        } else {
            set conf_changed 1
        }

        if {$tcldefs_f} { 
    
            set conf_changed [expr $conf_changed | [merge $currentdefs]]

            if {$conf_changed} { 
                ngis::log "file configurazione Tcl esistente, eseguiamo backup e merge" notice

                set backup_filename "ngis_conf-[clock format [clock seconds] -format "%Y%m%d%H%M%S"].tcl"
                #file copy -force $currentdefs $backup_filename
            }
        }

        if {$conf_changed} {
            ngis::log "rigenerazione della configurazione" notice
            sections_database
            generate    $currentdefs
            generate_sh $currentdefs_sh
        }
    }
    namespace export init

    namespace ensemble create
}

