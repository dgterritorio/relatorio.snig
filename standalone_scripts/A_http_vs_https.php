<?php
// Get the folder where the script is saved
$script_dir = dirname(__FILE__);
$params_file = $script_dir . '/connection_parameters.txt';

// Load connection parameters from file
$params = parse_ini_file($params_file);

$host = $params['HOST'];
$port = '5432';
$dbname = $params['DB_NAME'];
$user = $params['USERNAME'];
$password = $params['PASSWORD'];

// Connect to the PostgreSQL database
$conn = pg_connect("host=$host port=$port dbname=$dbname user=$user password=$password");

if (!$conn) {
    die("Connection failed: " . pg_last_error());
}

// Query the view
$query = 'SELECT gid, url_start, count FROM stats_and_metrics._01_group_urls_by_http_protocol';
$result = pg_query($conn, $query);

if (!$result) {
    die("Query failed: " . pg_last_error());
}

// Render the HTML body
?>

<b style="font-size: 24px;"><a href="/pages/_01_group_urls_by_http_protocol.csv">HTTP vs HTTPS</a></b>

<table>
    <tr>
        <th>URL Start</th>
        <th>Count</th>
    </tr>

    <?php while ($row = pg_fetch_assoc($result)): ?>
        <tr>
            <td><?php echo htmlspecialchars($row['url_start']); ?></td>
            <td><?php echo htmlspecialchars($row['count']); ?></td>
        </tr>
    <?php endwhile; ?>
</table>

<?php
// Close the connection
pg_close($conn);
?>
