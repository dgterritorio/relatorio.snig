#!/bin/bash

BASEFOLDER="/tmp"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FAILED_LOG="$BASEFOLDER/SNIG_failed_downloads.log"
INPUT_CSV="$BASEFOLDER/CSW_RECORDS_CSV/csw_records_csv.csv"
METADATA_DIR="$BASEFOLDER/SNIG_GEONETWORK_METADATA"

mkdir -p "$METADATA_DIR"

# Function to attempt downloads given an input list of UUIDs
download_records() {
  local input_file="$1"
  : > "$FAILED_LOG"  # clear old log

  while IFS="$" read -r uuid other_fields; do
    [[ -z "$uuid" ]] && continue
    echo "Downloading SNIG/GEONETWORK metadata for record $uuid"

    STATUS=$(wget --server-response -q -O "$METADATA_DIR/$uuid.xml" \
      "https://snig.dgterritorio.gov.pt/rndg/srv/api/records/$uuid/formatters/xml" 2>&1 | \
      awk '/^  HTTP/{print $2}' | tail -n1)

    if [[ -z "$STATUS" || "$STATUS" != "200" ]]; then
      echo "❌ Failed to download $uuid (HTTP status: ${STATUS:-unknown})"
      echo "$uuid" >> "$FAILED_LOG"
      rm -f "$METADATA_DIR/$uuid.xml"
    else
      echo "✅ Successfully downloaded $uuid"
    fi
  done < "$input_file"
}

# First pass — from main CSV
echo "---- First pass ----"
download_records "$INPUT_CSV"

# Retry loop
RETRY_COUNT=0
MAX_RETRIES=10  # stop if it's looping too much

while [[ -s "$FAILED_LOG" && $RETRY_COUNT -lt $MAX_RETRIES ]]; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo
  echo "---- Retry attempt #$RETRY_COUNT ----"

  # Prepare a temporary list with only failed UUIDs
  TMP_RETRY_LIST="$BASEFOLDER/retry_list.txt"
  awk '{print $1"$"}' "$FAILED_LOG" > "$TMP_RETRY_LIST"

  download_records "$TMP_RETRY_LIST"
done

echo
if [[ -s "$FAILED_LOG" ]]; then
  echo "⚠️  Some downloads still failed after $RETRY_COUNT attempts."
  echo "See remaining failures in: $FAILED_LOG"
else
  echo "✅ All downloads successful after $RETRY_COUNT attempts!"
fi

done < "$BASEFOLDER/CSW_RECORDS_CSV/csw_records_csv.csv"
