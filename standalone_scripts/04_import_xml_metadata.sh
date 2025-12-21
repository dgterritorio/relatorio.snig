#!/bin/bash

# --------------------------------------------------------------------
# Load database connection parameters
# --------------------------------------------------------------------
source connection_parameters.txt

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# --------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------
TABLE_NAME="testsuite.xml_metadata"

# --------------------------------------------------------------------
# Create a temporary file to store the list of current XML filenames
# --------------------------------------------------------------------
temp_file=$(mktemp)

# Collect all XML filenames (without .xml extension)
find "$BASEFOLDER/SNIG_GEONETWORK_METADATA" -name "*.xml" -exec basename {} .xml \; > "$temp_file"

# --------------------------------------------------------------------
# Import each XML file into the PostgreSQL table
# --------------------------------------------------------------------
for file in "$BASEFOLDER/SNIG_GEONETWORK_METADATA"/*.xml; do
    # Skip if no XML files are found
    [ -e "$file" ] || { echo "No XML files found."; break; }

    # Extract the filename without the .xml extension
    filename=$(basename "$file" .xml)

    # Determine if the file is empty
    if [ ! -s "$file" ]; then
        is_empty="TRUE"
        content=""
    else
        is_empty="FALSE"
        # Read file content and escape single quotes for SQL insertion
        content=$(cat "$file" | sed "s/'/''/g")
    fi

    # Insert a new record for this file
    psql -h "$HOST" -U "$USERNAME" -d "$DB_NAME" -c "
        INSERT INTO $TABLE_NAME (filename, content, is_empty, deleted)
        VALUES ('$filename', '$content', $is_empty, FALSE);
    " || { echo "Error importing $file."; continue; }

    echo "Imported $file successfully."
done

# --------------------------------------------------------------------
# Update 'deleted' status for files that are no longer present
# --------------------------------------------------------------------
psql -h "$HOST" -U "$USERNAME" -d "$DB_NAME" <<EOF
-- Create a temporary table to hold current filenames
CREATE TEMP TABLE temp_filenames (filename TEXT);

-- Load filenames from the temp file via STDIN
COPY temp_filenames (filename) FROM STDIN;
$(cat "$temp_file")
\.

-- Mark all records as deleted
UPDATE $TABLE_NAME SET deleted = TRUE;

-- Unmark records corresponding to currently existing files
UPDATE $TABLE_NAME
SET deleted = FALSE
WHERE filename IN (SELECT filename FROM temp_filenames);

-- Drop the temporary table
DROP TABLE temp_filenames;
EOF

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------
rm "$temp_file"
