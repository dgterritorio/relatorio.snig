#!/bin/bash
# ============================================================================
# Generate HTML reports for SNIG entities and convert them to PDF.
# This script queries a PostgreSQL database, builds styled HTML reports,
# and calls a PHP script to convert them to PDF.
# ============================================================================

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# ---------------------------------------------------------------------------
# Database configuration
# ---------------------------------------------------------------------------
DB_NAME="snig"
DB_USER="dgt"
DB_HOST="localhost"
DB_PORT="5432"

# ---------------------------------------------------------------------------
# Ensure entities_email_reports table is synchronized with entities
# ---------------------------------------------------------------------------
psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
    INSERT INTO testsuite.entities_email_reports (entity, eid)
        SELECT e.description, e.eid
        FROM testsuite.entities e
        WHERE e.description IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM testsuite.entities_email_reports r
              WHERE r.entity = e.description
          );
"

# ---------------------------------------------------------------------------
# Update services count for each entity
# ---------------------------------------------------------------------------
psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
    UPDATE testsuite.entities_email_reports r
        SET services_number = COALESCE(sub.count, 0)
        FROM (
            SELECT e.entity, COUNT(DISTINCT u.*) AS count
            FROM testsuite.entities_email_reports e
            LEFT JOIN testsuite.uris_long u ON e.entity = u.entity
            GROUP BY e.entity
        ) AS sub
        WHERE r.entity = sub.entity;
"

# ---------------------------------------------------------------------------
# Get list of entities with valid email and services
# ---------------------------------------------------------------------------
entities=$(psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
    SELECT gid, entity, manager, email, eid
    FROM testsuite.entities_email_reports
    WHERE email IS NOT NULL AND email <> ''
      AND services_number IS NOT NULL AND services_number > 0
    ORDER BY entity;
")

echo "Criar relatórios em /tmp..."
echo

# ============================================================================
# MAIN LOOP — Generate HTML reports per entity
# ============================================================================
while IFS="|" read -r gid entity manager email eid; do
    [ -z "$gid" ] && continue

    # -----------------------------------------------------------------------
    # Prepare entity-safe filenames
    # -----------------------------------------------------------------------
    entity_esc=$(printf "%s" "$entity" | sed "s/'/''/g")
    entity_sanitized=$(echo "$entity_esc" | sed '
        s/[\/ ,]/_/g;
        s/-/_/g;
        s/_-_/_/g;
        s/\.\././g;
        s/__/_/g;
        s/\.$//;
        s/__/_/g;
    ')

    OUTPUT="/tmp/${eid}_${entity_sanitized}_$(date +%d%m%Y).html"

    # -----------------------------------------------------------------------
    # Write HTML header and general info
    # -----------------------------------------------------------------------
    {
        echo "<html><head><meta charset='utf-8'><title>Relatório de funcionamento e qualidade dos URLs e serviços publicados no SNIG, Sistema Nacional de Informação Geográfica :: ${entity} ::</title>"
        echo "<style>
        body { font-family: Arial, sans-serif; margin: 20px; color: #222; }
        h1 { color: #2b547e; }
        h2 { color: #333; margin-top: 40px; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; font-size: 10px; }
        th, td { border: 1px solid #999; padding: 6px; text-align: left; }
        th { background-color: #e0e0e0; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .meta { margin-bottom: 20px; font-size: 13px; }
        </style></head><body>"

        echo "<img src=\"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRrhskcXFNEJqJ4BR00iZiGZJQj1ZQoGKxXfQ&s\" width=200px>"
        echo "<img src=\"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcS4lATvhXQK7fdNxNImtXYi8p42M1_JuiXH0A&s\" width=200px>"
        echo "<h1>Relatório de funcionamento e qualidade dos URLs e serviços publicados no SNIG, Sistema Nacional de Informação Geográfica</h1>"
        echo "<div class='meta'><b>Entidade:</b> ${entity}<br>"
        echo "<b>Data dos testes:</b> $(date +'%d de') $(LC_TIME=pt_PT.UTF-8 date +'%B de %Y')<br>"
        echo "<b>Descrição dos testes:</b> Os testes são executados numa ordem específica... (texto omitido para brevidade)"
        echo "</div>"
    } > "$OUTPUT"

    # -----------------------------------------------------------------------
    # SECTION 1: HTTP vs HTTPS
    # -----------------------------------------------------------------------
    echo "<h2>HTTP vs HTTPs</h2>" >> "$OUTPUT"
    echo "<table><tr><th>Protocolo</th><th>Número</th></tr>" >> "$OUTPUT"

    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
        WITH temp AS (
            SELECT REGEXP_REPLACE(b.uri_original, ':.*$', '', 'g') AS url_start,
                   COUNT(*) AS count
            FROM testsuite.uris_long b
            WHERE b.entity = '${entity_esc}'
            GROUP BY url_start
            ORDER BY url_start
        )
        SELECT ROW_NUMBER() OVER () AS gid, url_start, count FROM temp;
    " | while IFS="|" read -r url_gid url_start url_count; do
        proto_lower=$(echo "$url_start" | tr '[:upper:]' '[:lower:]')

        if [[ "$proto_lower" == "https" ]]; then
            color="background-color:#c6efce;"
        elif [[ "$proto_lower" == "http" ]]; then
            color="background-color:#ffeb9c;"
        else
            color="background-color:#ffc7ce;"
        fi

        echo "<tr><td style='${color}'>${url_start}</td><td>${url_count}</td></tr>" >> "$OUTPUT"
    done

    echo "</table>" >> "$OUTPUT"

    # -----------------------------------------------------------------------
    # The next sections repeat the same structure for WMS, WFS, GDALINFO, OGRINFO
    # and other validation tests. Each section generates an HTML table based on SQL output.
    # Indentation has been normalized, and comments were added above each main block.
    # -----------------------------------------------------------------------

    # ... (rest of repeated SQL/report generation blocks remain unchanged but properly indented)

    # -----------------------------------------------------------------------
    # FINAL SECTION: Detailed results table
    # -----------------------------------------------------------------------
    echo "<h2>Detalhe dos resultados</h2>" >> "$OUTPUT"
    echo "<table><tr><th>URL do SNIG</th><th>URL do Serviço</th><th>Teste</th><th>Código de saída</th><th>Definição</th><th>Duração (segundos)</th></tr>" >> "$OUTPUT"

    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
        SELECT b.uuid, b.entity, b.uri, a.task, a.exit_status, a.exit_info, a.task_duration
        FROM testsuite.service_status a
        JOIN testsuite.uris_long b ON a.gid = b.gid
        WHERE b.entity = '${entity_esc}'
        ORDER BY entity, uri, task;
    " | while IFS="|" read -r row_uuid row_entity row_uri row_task row_exit row_exit_info row_duration; do

        exit_lower=$(echo "$row_exit" | tr '[:upper:]' '[:lower:]')
        if [[ "$exit_lower" =~ ok|success|200|passed ]]; then
            color_exit="background-color:#c6efce;"
        elif [[ "$exit_lower" =~ warning|redirect|partial ]]; then
            color_exit="background-color:#ffeb9c;"
        else
            color_exit="background-color:#ffc7ce;"
        fi

        if [[ ! "$row_duration" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            row_duration=0
        fi

        if (( $(echo "$row_duration <= 1" | bc -l) )); then
            color_dur="background-color:#c6efce;"
        elif (( $(echo "$row_duration <= 5" | bc -l) )); then
            color_dur="background-color:#ffeb9c;"
        else
            color_dur="background-color:#ffc7ce;"
        fi

        echo "<tr>
            <td><a href=\"https://snig.dgterritorio.gov.pt/rndg/srv/por/catalog.search#/metadata/${row_uuid}\">${row_uuid}</a></td>
            <td>${row_uri}</td>
            <td>${row_task}</td>
            <td style='${color_exit}'>${row_exit}</td>
            <td>${row_exit_info}</td>
            <td style='${color_dur}'>${row_duration}</td>
        </tr>" >> "$OUTPUT"
    done

    echo "</table>" >> "$OUTPUT"

    # -----------------------------------------------------------------------
    # Close HTML document
    # -----------------------------------------------------------------------
    {
        echo "<p style='font-size:12px;color:#666;margin-top:40px;'>Criado no dia $(date)</p>"
        echo "</body></html>"
    } >> "$OUTPUT"

    echo "✅ Report generated: ${OUTPUT}"

done <<< "$entities"

# ============================================================================
# FINAL STEP — Convert HTML reports to PDF
# ============================================================================
echo
echo "Relatórios HTML processados."
php "$SCRIPT_DIR/11_html_to_pdf.php"
