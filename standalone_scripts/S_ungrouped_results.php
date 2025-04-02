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
$query = 'SELECT entity,uri,task,exit_status,task_duration FROM stats_and_metrics._00_ungrouped_results';
$result = pg_query($conn, $query);

if (!$result) {
    die("Query failed: " . pg_last_error());
}

// Render the HTML body
?>

<b style="font-size: 24px;"><a href="/pages/_00_ungrouped_results.csv">Ungrouped results</a></b>
<br/><br/>
<table>
    <tr>
        <th>Entity</th>
        <th>Tested URL</th>
        <th>Task</th>
        <th>Exit Status</th>
        <th>Duration</th>
    </tr>

    <?php while ($row = pg_fetch_assoc($result)): ?>
        <tr>
            <td><?php echo htmlspecialchars($row['entity']); ?></td>
            <td><a href="<?php echo htmlspecialchars($row['uri']); ?>" target="_blank"><?php echo htmlspecialchars(substr($row['uri'], 0, 50)) . '...'; ?></a></td>
            <td><?php echo htmlspecialchars($row['task']); ?></td>
            <td><?php echo htmlspecialchars($row['exit_status']); ?></td>
            <td><?php echo htmlspecialchars($row['task_duration']); ?></td>
        </tr>
    <?php endwhile; ?>
</table>

<?php
// Close the connection
pg_close($conn);
?>
