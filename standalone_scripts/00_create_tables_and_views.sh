#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PARENT_DIR=$(cd "$(dirname "$0")/.." && pwd)

# Import common PostgreSQL connection parameters
source "$SCRIPT_DIR/connection_parameters.txt"

psql -U $USERNAME -d $DB_NAME -h $HOST -f "$PARENT_DIR/tables_and_views/create_tables_and_views.sql"
