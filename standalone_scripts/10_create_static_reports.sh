#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

DB_NAME="snig"
DB_USER="dgt"
DB_HOST="localhost"
DB_PORT="5432"

    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
    INSERT INTO testsuite.entities_email_reports (entity,eid)
        SELECT e.description, e.eid
        FROM testsuite.entities e
        WHERE e.description IS NOT NULL
        AND NOT EXISTS (
        SELECT 1
        FROM testsuite.entities_email_reports r
        WHERE r.entity = e.description);"


    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
    UPDATE testsuite.entities_email_reports r
        SET services_number = COALESCE(sub.count, 0)
        FROM (
            SELECT e.entity, COUNT(DISTINCT u.*) AS count
            FROM testsuite.entities_email_reports e
            LEFT JOIN testsuite.uris_long u ON e.entity = u.entity
            GROUP BY e.entity
        ) AS sub
        WHERE r.entity = sub.entity;"


entities=$(psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
    SELECT gid, entity, manager, email, eid
    FROM testsuite.entities_email_reports
    ORDER BY entity;
")

echo "Criar relatorios em /tmp..."
echo

while IFS="|" read -r gid entity manager email eid; do
    [ -z "$gid" ] && continue
    entity_esc=$(printf "%s" "$entity" | sed "s/'/''/g")
    entity_sanitized=$(echo "$entity_esc" | sed '
        s/[\/ ,]/_/g;
        s/-/_/g;
        s/_-_/_/g;
        #s/_–_/_/g;
        s/\.\././g;
        s/__/_/g;
        s/\.$//;
        s/__/_/g;
        ')

    OUTPUT="/tmp/${eid}_${entity_sanitized}_$(date +%d%m%Y).html"

    {
    echo "<html><head><meta charset='utf-8'><title>Relatório de funcionamento e qualidade dos URLs e serviços publicados no SNIG, Sistema Nacional de Informação Geográfica :: ${entity} ::</title>"
        echo "<style>
        body {
          font-family: Arial, sans-serif;
          margin: 20px;
          color: #222;
        }
        h1 {
          color: #2b547e;
        }
        h2 {
          color: #333;
          margin-top: 40px;
        }
        table {
          border-collapse: collapse;
          width: 100%;
          margin-top: 10px;
          font-size: 10px;
        }
        th, td {
          border: 1px solid #999;
          padding: 6px;
          text-align: left;
        }
        th {
          background-color: #e0e0e0;
        }
        tr:nth-child(even) {
          background-color: #f9f9f9;
        }
        .meta {
          margin-bottom: 20px;
          font-size: 13px;
        }
        </style></head><body>"

    echo "<img src=\"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRrhskcXFNEJqJ4BR00iZiGZJQj1ZQoGKxXfQ&s\" width=200px>"
    echo "<img src=\"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcS4lATvhXQK7fdNxNImtXYi8p42M1_JuiXH0A&s\" width=200px>"

    echo "<h1>Relatório de funcionamento e qualidade dos URLs e serviços publicados no SNIG,  Sistema Nacional de Informação Geográfica</h1>"
    echo "<div class='meta'><b>Entidade:</b> ${entity}<br>"
    #echo "<b>Responsável:</b> ${manager}<br>"
    #echo "<b>Endereço E-mail:</b> ${email}<br>"
    echo "<b>Data dos testes:</b> $(date +'%d de') $(LC_TIME=pt_PT.UTF-8 date +'%B de %Y')<br>"

    echo "<b>Descrição dos testes:</b> Os testes são executados numa ordem especifica, quando um teste de um URL/serviço falha,
         os testes seguintes não são executados.<br><br>
         O <i>timeout</i> dos testes é de 20 segundos, ao fim desse periodo é interrompido o teste para evitar respostas com tempos muito
         longos e é atribuido erro ao resultado.<br><br>
         Os testes executados são:<br><br>
         1) <i>Congruence</i>: Verifica se os URLs dos serviços são formalmente corretos.<br><br>
         2) <i>Código de estado HTTP</i>: o URL/serviço deve devolver <i>status code</i> 200 (o pedido foi bem sucedido).<br><br>
         3) <i>Validade da resposta ao pedido GetCapabilities</i>: o documento XML resultante de pedidos
         standard OGC WMS/WFS \"<i>GetCapabilities</i>\" deve ser valido.<br><br>
         4) <i>Validade da resposta ao pedido GDALINFO/OGRINFO</i>: a resposta ao pedido de informações
         feita com as ferramentas <a href=\"https://gdal.org/en/stable/programs/gdalinfo.html\"><b><i>gdalinfo</i></b></a> (gdalinfo WMS:\"URL\") e
         <a href=\"https://gdal.org/en/stable/programs/ogrinfo.html\"><b><i>ogrinfo</i></b></a> (ogrinfo -so WFS:\"URL\")
         não deve conter erros.<br><br>
         A equipa SNIG/INSPIRE.
         </div>"

    } > "$OUTPUT"





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




    echo "<h2>Códigos de estado HTTP</h2>" >> "$OUTPUT"
    echo "<table><tr><th>Código de saída</th><th>Definição</th><th>Número</th><th>Duração média</th></tr>" >> "$OUTPUT"

    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
        WITH a AS (
            SELECT
                CASE
                    WHEN a.exit_info = 'Curl got nothing from the server' THEN 'Empty response'
                    WHEN a.exit_info = 'An error occurred during the SSL/TLS handshake' THEN 'SSL error'
                    WHEN a.exit_info LIKE 'http_status_code: 200%' THEN '200'
                    WHEN a.exit_info = 'Invalid HTTP status code 0' THEN 'Status code 0'
                    WHEN a.exit_info = 'Failure in receiving network data' THEN 'Network error'
                    WHEN a.exit_info = 'Failed to connect to host' THEN 'Cannot connect to host'
                    WHEN a.exit_info = 'Peer certificate cannot be authenticated with known CA certificates' THEN 'Certificates error'
                    WHEN a.exit_info LIKE 'Success with http code 200 after redir%' THEN '200 after 301/302 redirect'
                    WHEN a.exit_info = 'Invalid HTTP status code 301 after redir' THEN 'Error HTTP status code after redirect'
                    WHEN a.exit_info = 'Invalid HTTP status code 302 after redir' THEN 'Error HTTP status code after redirect'
                    WHEN a.exit_info LIKE 'Invalid HTTP status code%' AND a.exit_info NOT IN ('Invalid HTTP status code 301 after redir', 'Invalid HTTP status code 302 after redir') THEN RIGHT(a.exit_info, 3)
                    ELSE a.exit_info
                END AS status_code,
                COUNT(*) AS count,
                ROUND(avg(a.task_duration)::numeric, 3) AS ping_average
            FROM testsuite.service_status a
            JOIN testsuite.uris_long b ON a.gid = b.gid
            WHERE a.task = 'url_status_codes' AND b.entity = '${entity_esc}'
            GROUP BY 1
        ),
        temp AS (
            SELECT ROW_NUMBER() OVER () AS gid,
                   a.status_code,
                   CASE a.status_code
                       WHEN 'Empty response' THEN 'Empty response'
                       WHEN 'SSL error' THEN 'SSL error'
                       WHEN '000' THEN 'Timeout'
                       WHEN 'URL status code check failed on a 20 secs timeout error' THEN 'Timeout'
                       WHEN '200' THEN 'OK'
                       WHEN '200 after 301/302 redirect' THEN 'OK after redirect'
                       WHEN '201' THEN 'Created'
                       WHEN '202' THEN 'Accepted'
                       WHEN '204' THEN 'No Content'
                       WHEN '301' THEN 'Moved Permanently'
                       WHEN '302' THEN 'Found'
                       WHEN 'Error HTTP status code after redirect' THEN 'Error after redirect'
                       WHEN '400' THEN 'Bad Request'
                       WHEN '401' THEN 'Unauthorized'
                       WHEN '403' THEN 'Forbidden'
                       WHEN '404' THEN 'Not Found'
                       WHEN '500' THEN 'Internal Server Error'
                       WHEN '502' THEN 'Bad Gateway'
                       WHEN '503' THEN 'Service Unavailable'
                       WHEN '504' THEN 'Gateway Timeout'
                       WHEN '499' THEN 'Client Closed Request'
                       WHEN 'Error resolving the URL host name' THEN 'Hostname unknown'
                       WHEN 'Network error' THEN 'Network error'
                       WHEN 'Cannot connect to host' THEN 'Cannot connect to host'
                       WHEN 'Certificates error' THEN 'Certificates error'
                       WHEN 'Status code 0' THEN 'To be investigated'
                       ELSE '' END AS definition,
                   a.count,
                   a.ping_average
            FROM a
        )
        SELECT gid, status_code, definition, count, ping_average FROM temp ORDER BY count DESC;
    " | while IFS="|" read -r http_gid status_code definition count avg; do
    color=""
    case "$status_code" in
        "200")
            color="background-color:#c6efce;" ;;
        "200 after 301/302 redirect")
            color="background-color:#ffeb9c;" ;;
        *)
            color="background-color:#ffc7ce;" ;;
    esac

    echo "<tr><td style='${color}'>${status_code}</td><td>${definition}</td><td>${count}</td><td>${avg}</td></tr>" >> "$OUTPUT"
    done
    echo "</table>" >> "$OUTPUT"







    echo "<h2>Validade da resposta ao pedido WMS \"GetCapabilities\"</h2><table><tr><th>Código de saída</th><th>Definição</th><th>Número</th><th>Duração média</th></tr>" >> "$OUTPUT"

    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
        WITH c AS (
            SELECT
                a.exit_info AS status_code,
                a.exit_status,
                COUNT(*) AS count,
                ROUND(avg(a.task_duration)::numeric, 3) AS ping_average
            FROM testsuite.service_status a
            JOIN testsuite.uris_long b ON a.gid = b.gid
            WHERE a.task = 'wms_capabilities' AND b.entity = '${entity_esc}'
            GROUP BY a.exit_info, a.exit_status
        ),
        temp AS (
            SELECT ROW_NUMBER() OVER () AS gid,
                   c.status_code,
                   c.exit_status AS definition,
                   c.count,
                   c.ping_average
            FROM c
        )
        SELECT gid, status_code, definition, count, ping_average
        FROM temp
        ORDER BY count DESC;
    " | while IFS="|" read -r gid_wms status_code exit_status count avg; do
    color=""
    def_lower=$(echo "$exit_status" | tr '[:upper:]' '[:lower:]')
    if [[ "$def_lower" == "ok" ]]; then
        color="background-color:#c6efce;"
    elif [[ "$def_lower" == "warning" ]]; then
        color="background-color:#ffeb9c;"
    elif [[ "$def_lower" == "error" ]]; then
        color="background-color:#ffc7ce;"
    fi

        echo "<tr><td>${status_code}</td><td style='${color}'>${exit_status}</td><td>${count}</td><td>${avg}</td></tr>" >> "$OUTPUT"
    done
    echo "</table>" >> "$OUTPUT"






    echo "<h2>Validade da resposta ao pedido WFS \"GetCapabilities\"</h2><table><tr><th>Código de saída</th><th>Definição</th><th>Número</th><th>Duração média</th></tr>" >> "$OUTPUT"

    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
        WITH c AS (
            SELECT
                a.exit_info AS status_code,
                a.exit_status,
                COUNT(*) AS count,
                ROUND(avg(a.task_duration)::numeric, 3) AS ping_average
            FROM testsuite.service_status a
            JOIN testsuite.uris_long b ON a.gid = b.gid
            WHERE a.task = 'wfs_capabilities' AND b.entity = '${entity_esc}'
            GROUP BY a.exit_info, a.exit_status
        ),
        temp AS (
            SELECT ROW_NUMBER() OVER () AS gid,
                   c.status_code,
                   c.exit_status AS definition,
                   c.count,
                   c.ping_average
            FROM c
        )
        SELECT gid, status_code, definition, count, ping_average
        FROM temp
        ORDER BY count DESC;
    " | while IFS="|" read -r gid_wfs status_code exit_status count avg; do

    color=""
    def_lower=$(echo "$exit_status" | tr '[:upper:]' '[:lower:]')
    if [[ "$def_lower" == "ok" ]]; then
        color="background-color:#c6efce;"
    elif [[ "$def_lower" == "warning" ]]; then
        color="background-color:#ffeb9c;"
    elif [[ "$def_lower" == "error" ]]; then
        color="background-color:#ffc7ce;"
    fi

        echo "<tr><td>${status_code}</td><td style='${color}'>${exit_status}</td><td>${count}</td><td>${avg}</td></tr>" >> "$OUTPUT"
    done
    echo "</table>" >> "$OUTPUT"





    echo "<h2>Validade da resposta ao pedido WMS GDALINFO</h2><table><tr><th>Código de saída</th><th>Definição</th><th>Número</th><th>Duração média</th></tr>" >> "$OUTPUT"

    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
         WITH c AS (
         SELECT a.exit_info AS status_code,
            a.exit_status,
            count(*) AS count,
            ROUND(avg(a.task_duration)::numeric, 3) AS ping_average
           FROM testsuite.service_status a
                   JOIN testsuite.uris_long b ON a.gid = b.gid
          WHERE a.task::text = 'wms_gdal_info'::text AND b.entity = '${entity_esc}'
          GROUP BY a.exit_info, a.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            c.status_code,
            c.exit_status AS definition,
            c.count,
            c.ping_average
           FROM c
        )
                 SELECT gid,
                        status_code,
                        definition,
                        count,
                        ping_average
                   FROM temp
                  ORDER BY count DESC;
    " | while IFS="|" read -r gid_wms status_code exit_status count avg; do

    color=""
    def_lower=$(echo "$exit_status" | tr '[:upper:]' '[:lower:]')
    if [[ "$def_lower" == "ok" ]]; then
        color="background-color:#c6efce;"
    elif [[ "$def_lower" == "warning" ]]; then
        color="background-color:#ffeb9c;"
    elif [[ "$def_lower" == "error" ]]; then
        color="background-color:#ffc7ce;"
    fi

        echo "<tr><td>${status_code}</td><td style='${color}'>${exit_status}</td><td>${count}</td><td>${avg}</td></tr>" >> "$OUTPUT"
    done
    echo "</table>" >> "$OUTPUT"





    echo "<h2>Validade da resposta ao pedido WFS OGRINFO</h2><table><tr><th>Código de saída</th><th>Definição</th><th>Número</th><th>Duração média</th></tr>" >> "$OUTPUT"

    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
         WITH c AS (
         SELECT a.exit_info AS status_code,
            a.exit_status,
            count(*) AS count,
            ROUND(avg(a.task_duration)::numeric, 3) AS ping_average
           FROM testsuite.service_status a
                   JOIN testsuite.uris_long b ON a.gid = b.gid
          WHERE a.task::text = 'wfs_ogr_info'::text AND b.entity = '${entity_esc}'
          GROUP BY a.exit_info, a.exit_status
        ), temp AS (
         SELECT row_number() OVER () AS gid,
            c.status_code,
            c.exit_status AS definition,
            c.count,
            c.ping_average
           FROM c
        )
                 SELECT gid,
                        status_code,
                        definition,
                        count,
                        ping_average
                   FROM temp
                  ORDER BY count DESC;
    " | while IFS="|" read -r gid_wfs status_code exit_status count avg; do

    color=""
    def_lower=$(echo "$exit_status" | tr '[:upper:]' '[:lower:]')
    if [[ "$def_lower" == "ok" ]]; then
        color="background-color:#c6efce;"
    elif [[ "$def_lower" == "warning" ]]; then
        color="background-color:#ffeb9c;"
    elif [[ "$def_lower" == "error" ]]; then
        color="background-color:#ffc7ce;"
    fi

        echo "<tr><td>${status_code}</td><td style='${color}'>${exit_status}</td><td>${count}</td><td>${avg}</td></tr>" >> "$OUTPUT"
    done
    echo "</table>" >> "$OUTPUT"





    echo "<h2>Detalhe dos resultados</h2>" >> "$OUTPUT"
    echo "<table><tr><th>URL do SNIG</th><th>URL do Serviço</th><th>Teste</th><th>Código de saída</th><th>Definição</th><th>Duração (segundos)</th></tr>" >> "$OUTPUT"

    psql -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t -A -F"|" -c "
        SELECT b.uuid,b.entity, b.uri, a.task, a.exit_status, a.exit_info, a.task_duration
        FROM testsuite.service_status a
        JOIN testsuite.uris_long b ON a.gid = b.gid
        WHERE b.entity = '${entity_esc}'
        ORDER BY entity, uri, task;
    " | while IFS="|" read -r row_uuid row_entity row_uri row_task row_exit row_exit_info row_duration; do

    color=""
    exit_lower=$(echo "$row_exit" | tr '[:upper:]' '[:lower:]')
    if [[ "$exit_lower" =~ ok|success|200|passed ]]; then
        color="background-color:#c6efce;"
    elif [[ "$exit_lower" =~ warning|redirect|partial ]]; then
        color="background-color:#ffeb9c;"
    else
        color="background-color:#ffc7ce;"
    fi

        echo "<tr><td><a href=\"https://snig.dgterritorio.gov.pt/rndg/srv/por/catalog.search#/metadata/${row_uuid}\">${row_uuid}</a></td><td>${row_uri}</td><td>${row_task}</td><td style='${color}'>${row_exit}</td><td>${row_exit_info}</td><td>${row_duration}</td></tr>" >> "$OUTPUT"
    done
    echo "</table>" >> "$OUTPUT"





    {
    echo "<p style='font-size:12px;color:#666;margin-top:40px;'>Criado no dia $(date)</p>"
    echo "</body></html>"
    } >> "$OUTPUT"

    echo "✅ Report generated: ${OUTPUT}"
done <<< "$entities"

echo
echo "Relatórios HTML processados."

php "$SCRIPT_DIR/11_html_to_pdf.php"
