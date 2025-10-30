#!/bin/bash

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Generate HTML code with statistics
$SCRIPT_DIR/08_generate_html_tables.sh

# Export statistics to CSV
$SCRIPT_DIR/09_export_metrics_to_csv.sh
