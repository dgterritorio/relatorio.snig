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
$query = 'SELECT gid, status_code, definition, count, ping_average FROM stats_and_metrics._02_group_by_http_status_code_global';
$result = pg_query($conn, $query);

if (!$result) {
    die("Query failed: " . pg_last_error());
}

// Render the body HTML
header('Content-Type: text/html');
?>
<div id="B"></div>
<b style="font-size: 24px;"><a href="/pages/_02_group_by_http_status_code_global.csv">HTTP STATUS CODES</a></b>
<br/><br/>
<table>
    <tr>
        <th>Status Code</th>
        <th>Definition</th>
        <th>Count</th>
        <th>Ping Average</th>
    </tr>

<?php
$bgColorDefinition = '';
$bgColorPing = '';
$definition = '';
$ping_average = '';
?>

    <?php while ($row = pg_fetch_assoc($result)): ?>
    
<?php
if (str_starts_with(htmlspecialchars($row['definition']), "OK")) {
    $bgColorDefinition = 'green';
} else {
    $bgColorDefinition = 'red';
}
    
if ((str_starts_with(htmlspecialchars($row['definition']), "OK")) && (htmlspecialchars($row['ping_average']) < 1)) {
    $bgColorPing = 'green';
}
 elseif ((str_starts_with(htmlspecialchars($row['definition']), "OK")) && (htmlspecialchars($row['ping_average']) >= 1) && (htmlspecialchars($row['ping_average']) < 2)) {
    $bgColorPing = 'orange';
}
elseif ((str_starts_with(htmlspecialchars($row['definition']), "OK")) && (htmlspecialchars($row['ping_average']) >= 2)) {
    $bgColorPing = 'red';
}
else {
    $bgColorPing = '';
}
?>
        <tr>
            <td><?php echo htmlspecialchars($row['status_code']); ?></td>
            <td style="background-color: <?php echo $bgColorDefinition; ?>;"><?php echo htmlspecialchars($row['definition']); ?></td>
            <td><?php echo htmlspecialchars($row['count']); ?></td>
            <td style="background-color: <?php echo $bgColorPing; ?>;"><?php echo htmlspecialchars(number_format((float)$row['ping_average'], 2)); ?></td>
        </tr>
    <?php endwhile; ?>
</table>

<?php
// Close the connection
pg_close($conn);
?>
