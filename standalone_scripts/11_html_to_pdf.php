<?php
require_once __DIR__ . '/vendor/autoload.php';

use Mpdf\Mpdf;
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

$dbname = 'snig';
$dbuser = 'dgt';
$dbhost = 'localhost';
$dbport = '5432';
$report_dir_html = '/tmp';
$report_dir_pdf  = '/tmp/reports_pdf';

$email_from     = 'snig@dgterritorio.pt';
$smtp_host      = '192.168.10.70';
$smtp_port      = 25;


    setlocale(LC_TIME, 'pt_PT.UTF-8', 'pt_PT', 'pt', 'portuguese');
    $data_envio = strftime('%e de %B de %Y'); // e.g. "26 de Outubro de 2025"

    if (empty(trim($data_envio)) || $data_envio === ' de ') {
        $fmt = new IntlDateFormatter('pt_PT', IntlDateFormatter::LONG, IntlDateFormatter::NONE);
        $data_envio = $fmt->format(new DateTime());
    }


$email_body     = "Ex.mo(a) Senhor(a),\n\nNo âmbito do processo de verificação e reporte periódico do funcionamento dos serviços dos conjuntos de dados abertos publicados no Registo Nacional dos Dados Geográficos do SNIG, envia-se em anexo o relatório dos testes de funcionamento e qualidade dos serviços publicados no SNIG pela sua entidade, realizados a $data_envio.\n\nAgradecemos a sua intervenção em conformidade para corrigir com a maior celeridade possível os eventuais problemas e assim assegurar a utilização dos respetivos serviços publicados de forma contínua e permanente pelos cidadãos, entidades e empresas.\n\nNo caso de verificar que o serviço está a funcionar corretamente e não consiga replicar o erro, agradecemos que nos contacte com a identificação explicita do erro, teste e serviço.\n\nCom os melhores cumprimentos,\nA equipa SNIG/INSPIRE.";


if (!is_dir($report_dir_pdf)) {
    mkdir($report_dir_pdf, 0775, true);
}

$conn = pg_connect("host=$dbhost dbname=$dbname user=$dbuser port=$dbport");
if (!$conn) {
    die("❌ Could not connect to PostgreSQL\n");
}

$query = "
    SELECT gid, entity, email, services_number, eid
    FROM testsuite.entities_email_reports
    WHERE email IS NOT NULL AND email <> ''
      AND services_number IS NOT NULL AND services_number > 0
    ORDER BY eid;
";

$result = pg_query($conn, $query);
if (!$result) {
    die("❌ Query failed: " . pg_last_error($conn) . "\n");
}

while ($row = pg_fetch_assoc($result)) {
    $gid     = $row['gid'];
    $entity  = $row['entity'];
    $email   = trim($row['email']);
    $eid     = $row['eid'];

    $pattern = sprintf('%s/%s_*', $report_dir_html, $eid);
    $html_files = glob($pattern . '.html');

    if (empty($html_files)) {
        echo "⚠️ No HTML found for geid {$eid} ({$entity})\n";
        continue;
    }

    $html_file = $html_files[0];
    $pdf_file  = sprintf('%s/%s_%s.pdf', $report_dir_pdf, $eid, preg_replace('/[\/ ]+/', '_', $entity));

    try {
        $html_content = file_get_contents($html_file);
        $mpdf = new Mpdf(['tempDir' => sys_get_temp_dir()]);
        // Split WriteHTML into chunks if large
        foreach (str_split($html_content, 1000000) as $chunk) {
            $mpdf->WriteHTML($chunk);
        }
        $mpdf->Output($pdf_file, \Mpdf\Output\Destination::FILE);
        echo "✅ PDF generated: {$pdf_file}\n";
    } catch (Exception $e) {
        echo "❌ PDF generation failed for {$entity}: " . $e->getMessage() . "\n";
        continue;
    }

try {

    $subject_date = "Relatório de funcionamento e qualidade dos serviços publicados no SNIG: $data_envio";

        $mail = new PHPMailer(true);
        $mail->isSMTP();
        $mail->Host = $smtp_host;
        $mail->Port = $smtp_port;
        $mail->SMTPAuth = false;

    $mail->CharSet = 'UTF-8';
    $mail->Encoding = 'base64';

        $mail->setFrom($email_from, 'Direção-Geral do Território');
        $mail->addAddress($email);
        $mail->Subject = $subject_date;
        $mail->Body    = $email_body;
        $mail->addAttachment($pdf_file);

        $mail->send();
        echo "📨 Email sent to {$email} ({$entity})\n";
    } catch (Exception $e) {
        echo "❌ Failed to send email to {$email}: " . $mail->ErrorInfo . "\n";
    }
}

pg_close($conn);
echo "\nRelatórios PDF processados.\n";
