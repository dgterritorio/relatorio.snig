#!/bin/bash
#
#

function make_ok_result ()
{
    echo "ok {} {} {$1} {$(date +%s)}"
}

function make_error_result ()
{
    echo "error {$1} {$2} {$3} {$(date +%s)}"
}

function make_warning_result ()
{
    echo "warning {$1} {$2} {$3} {$(date +%s)}"
}
