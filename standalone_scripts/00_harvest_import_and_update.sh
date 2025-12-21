#!/bin/bash

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

$SCRIPT_DIR/01_download_csw_records.sh
$SCRIPT_DIR/02_csw_records_to_csv.sh
$SCRIPT_DIR/03_download_geonetwork_metadata.sh
$SCRIPT_DIR/04_import_xml_metadata.sh
$SCRIPT_DIR/05_geonetwork_metadata_to_csv.sh
$SCRIPT_DIR/06_add_type_and_version.sh
$SCRIPT_DIR/07_import_and_update_data.sh
