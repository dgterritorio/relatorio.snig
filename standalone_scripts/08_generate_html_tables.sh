#!/bin/bash

script_dir=$(dirname "$(realpath "$0")")
output="$script_dir/tables.html"

# Clean up the output file if it already exists
> "$output"

for php_file in "$script_dir"/[A-Z]*_*.php; do
    if [[ -f "$php_file" ]]; then
        html_file="${php_file%.php}.html"
        php "$php_file" > "$html_file"

        cat "$html_file" >> "$output"

        rm "$html_file"
    fi
done

echo "All files merged into $output"
cp "$script_dir/../monitor/website/pages/template.xml" "$script_dir/../monitor/website/pages/estatisticas.xml"

# Use awk to replace PLACEHOLDER by reading the file content directly
awk '
    BEGIN {
        while ((getline line < "'$output'") > 0)
            new_content = new_content line "\n";
        close("'$output'");
    }
    { gsub(/PLACEHOLDER/, new_content) }
    1
' "$script_dir/../monitor/website/pages/estatisticas.xml" > "$script_dir/../monitor/website/pages/estatisticas.xml.tmp"

mv "$script_dir/../monitor/website/pages/estatisticas.xml.tmp" "$script_dir/../monitor/website/pages/estatisticas.xml"
echo "PLACEHOLDER replaced in estatisticas.xml"
