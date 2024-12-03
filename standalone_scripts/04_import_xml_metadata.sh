#!/bin/bash

# Read connection parameters from file
source connection_parameters.txt

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Define table name
TABLE_NAME="testsuite.xml_metadata"

# Create a temporary file to store current filenames
temp_file=$(mktemp)

# Collect current filenames and save them to the temp file
find "$BASEFOLDER/SNIG_GEONETWORK_METADATA" -name "*.xml" -exec basename {} .xml \; > "$temp_file"

# Import XML files
for file in "$BASEFOLDER/SNIG_GEONETWORK_METADATA"/*.xml; do
    # Skip if no XML files are found
    [ -e "$file" ] || { echo "No XML files found."; break; }

    # Extract the filename without the .xml extension
    filename=$(basename "$file" .xml)

    # Check if the file is empty
    if [ ! -s "$file" ]; then
        is_empty="TRUE"
        content=""
    else
        is_empty="FALSE"
        content=$(cat "$file" | sed "s/'/''/g") # Escape single quotes for SQL
    fi

    # Insert a new record for the file
    psql -h "$HOST" -U "$USERNAME" -d "$DB_NAME" -c "
    INSERT INTO $TABLE_NAME (filename, content, is_empty, deleted)
    VALUES ('$filename', '$content', $is_empty, FALSE);
    " || { echo "Error importing $file."; continue; }

    echo "Imported $file successfully."
done

# Update the 'deleted' column for files not in the current folder
psql -h "$HOST" -U "$USERNAME" -d "$DB_NAME" <<EOF
-- Create a temporary table for the current files
CREATE TEMP TABLE temp_filenames (filename TEXT);

-- Load filenames from the temp file using STDIN
COPY temp_filenames (filename) FROM STDIN;
$(cat "$temp_file")
\.

-- Set all records to deleted = TRUE
UPDATE $TABLE_NAME SET deleted = TRUE;

-- Unmark records corresponding to current files
UPDATE $TABLE_NAME
SET deleted = FALSE
WHERE filename IN (SELECT filename FROM temp_filenames);

-- Drop the temporary table
DROP TABLE temp_filenames;
EOF

# Cleanup the temporary file
rm "$temp_file"
