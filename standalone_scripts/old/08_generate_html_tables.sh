#!/bin/bash

script_dir=$(dirname "$(realpath "$0")")
output_dir="/tmp"
output="$output_dir/tables.html"
header="$script_dir/../monitor/website/pages/template_header.xml"
footer="$script_dir/../monitor/website/pages/template_footer.xml"
final_output="$script_dir/../monitor/website/pages/estatisticas.xml"

# Clean up the output file if it already exists
> "$output"

# Step 1: Generate HTML from PHP pages and save them to /tmp
for php_file in "$script_dir"/[A-Z]*_*.php; do
    if [[ -f "$php_file" ]]; then
        html_file="$output_dir/$(basename "${php_file%.php}.html")"
        php "$php_file" > "$html_file"
    fi
done

# Step 2: Merge the HTML files in alphabetical order
cat $(ls "$output_dir"/[A-Z]*.html | sort) > "$output"

# Step 3: Combine header, HTML content, and footer
{
    cat "$header"
    cat "$output"
    cat "$footer"
} > "$final_output"

echo "HTML pages merged and saved to $final_output"
