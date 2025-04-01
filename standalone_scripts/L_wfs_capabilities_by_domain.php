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
$query = 'SELECT gid, uri_domain, status_code, definition, count, ping_average FROM stats_and_metrics._10_group_by_wfs_capabilities_validity_and_domain';
$result = pg_query($conn, $query);

if (!$result) {
    die("Query failed: " . pg_last_error());
}

// Render the body HTML
header('Content-Type: text/html');
?>

<b style="font-size: 24px;"><a href="/pages/_10_group_by_wfs_capabilities_validity_and_domain.csv">WFS CAPABILITIES DOCUMENT VALIDITY by Domain</a></b>
<br/><br/>
<table>
    <tr>
        <th>Entity</th>
        <th>Status Code</th>
        <th>Definition</th>
        <th>Count</th>
        <th>Ping Average</th>
    </tr>

    <?php while ($row = pg_fetch_assoc($result)): ?>
        <tr>
            <td><?php echo htmlspecialchars($row['uri_domain']); ?></td>
            <td><?php echo htmlspecialchars($row['status_code']); ?></td>
            <td><?php echo htmlspecialchars($row['definition']); ?></td>
            <td><?php echo htmlspecialchars($row['count']); ?></td>
            <td><?php echo htmlspecialchars(number_format((float)$row['ping_average'], 2)); ?></td>
        </tr>
    <?php endwhile; ?>
</table>

<?php
// Close the connection
pg_close($conn);
?>
