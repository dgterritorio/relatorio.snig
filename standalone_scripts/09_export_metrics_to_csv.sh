#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Import common PostgreSQL connection parameters
source "$SCRIPT_DIR/connection_parameters.txt"

# Output directory
OUTPUT_DIR="$SCRIPT_DIR/../monitor/website/pages"
mkdir -p "$OUTPUT_DIR"

# Get list of tables in the schema
TABLES=$(psql -h "$HOST" -p 5432 -U "$USERNAME" -d "$DB_NAME" -Atc \
         "SELECT table_name FROM information_schema.views WHERE table_schema = 'stats_and_metrics';")

# Export each table to CSV
for TABLE in $TABLES; do
    echo "Exporting $TABLE to $TABLE.csv"
    ogr2ogr -f "CSV" "$OUTPUT_DIR/$TABLE.csv" \
        PG:"dbname=$DB_NAME user=$USERNAME password=$PASSWORD host=$HOST port=5432" \
        -sql "SELECT * FROM stats_and_metrics.\"$TABLE\""
done

echo "Export completed."

cd "$OUTPUT_DIR" || exit 1

ZIP_FILE="estatisticas.zip"

if [ -f "$ZIP_FILE" ]; then
    echo "Removing existing $ZIP_FILE"
    rm -f "$ZIP_FILE"
fi

FILES_TO_ZIP=$(find . -maxdepth 1 -type f -name "_*.csv")

if [ -n "$FILES_TO_ZIP" ]; then
    echo "Zipping CSV files starting with '_' into $ZIP_FILE"
    zip "$ZIP_FILE" _*.csv
    echo "Created $ZIP_FILE successfully."
else
    echo "No CSV files starting with '_' found to zip."
fi
