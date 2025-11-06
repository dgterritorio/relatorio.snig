#!/bin/bash

# ------------------------------------------------------------------------------
# Script: Export PostgreSQL views to CSV and create a ZIP archive
# Description:
#   This script exports all views from the 'stats_and_metrics' schema
#   of a PostgreSQL database into CSV files, then compresses selected
#   CSVs (those starting with "_") into a ZIP archive.
# ------------------------------------------------------------------------------

# Get the absolute path to the script directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# ------------------------------------------------------------------------------
# Load PostgreSQL connection parameters from external file
#   Expected variables in 'connection_parameters.txt':
#     HOST, USERNAME, PASSWORD, DB_NAME
# ------------------------------------------------------------------------------
source "$SCRIPT_DIR/connection_parameters.txt"

# ------------------------------------------------------------------------------
# Define the output directory for CSV files
# ------------------------------------------------------------------------------
OUTPUT_DIR="$SCRIPT_DIR/../monitor/website/pages"
mkdir -p "$OUTPUT_DIR"

# ------------------------------------------------------------------------------
# Retrieve list of all views in schema 'stats_and_metrics'
# ------------------------------------------------------------------------------
TABLES=$(psql -h "$HOST" -p 5432 -U "$USERNAME" -d "$DB_NAME" -Atc \
         "SELECT table_name FROM information_schema.views WHERE table_schema = 'stats_and_metrics';")

# ------------------------------------------------------------------------------
# Export each view to a corresponding CSV file
# ------------------------------------------------------------------------------
for TABLE in $TABLES; do
    echo "Exporting $TABLE to $TABLE.csv"

    ogr2ogr -f "CSV" "$OUTPUT_DIR/$TABLE.csv" \
        PG:"dbname=$DB_NAME user=$USERNAME password=$PASSWORD host=$HOST port=5432" \
        -sql "SELECT * FROM stats_and_metrics.\"$TABLE\""
done

echo "Export completed."

# ------------------------------------------------------------------------------
# Move to the output directory for compression
# ------------------------------------------------------------------------------
cd "$OUTPUT_DIR" || exit 1

# Name of the resulting ZIP archive
ZIP_FILE="estatisticas.zip"

# ------------------------------------------------------------------------------
# Remove existing ZIP file if it exists
# ------------------------------------------------------------------------------
if [ -f "$ZIP_FILE" ]; then
    echo "Removing existing $ZIP_FILE"
    rm -f "$ZIP_FILE"
fi

# ------------------------------------------------------------------------------
# Find CSV files starting with "_" and zip them
# ------------------------------------------------------------------------------
FILES_TO_ZIP=$(find . -maxdepth 1 -type f -name "_*.csv")

if [ -n "$FILES_TO_ZIP" ]; then
    echo "Zipping CSV files starting with '_' into $ZIP_FILE"
    zip "$ZIP_FILE" _*.csv
    echo "Created $ZIP_FILE successfully."
else
    echo "No CSV files starting with '_' found to zip."
fi
