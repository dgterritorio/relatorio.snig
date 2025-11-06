<?php
require_once __DIR__ . '/vendor/autoload.php';

use Mpdf\Mpdf;
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

// ============================================================================
// CONFIGURATION
// ============================================================================

// Database configuration
$dbname          = 'snig';
$dbuser          = 'dgt';
$dbhost          = 'localhost';
$dbport          = '5432';

// Report directories
$report_dir_html = '/tmp';
$report_dir_pdf  = '/tmp/reports_pdf';

// Email configuration
$email_from = 'snig@dgterritorio.pt';
$smtp_host  = '192.168.10.70';
$smtp_port  = 25;

// ============================================================================
// DATE AND LOCALE SETUP
// ============================================================================
setlocale(LC_TIME, 'pt_PT.UTF-8', 'pt_PT', 'pt', 'portuguese');
$data_envio = strftime('%e de %B de %Y'); // e.g. "26 de Outubro de 2025"

// Fallback if strftime fails
if (empty(trim($data_envio)) || $data_envio === ' de ') {
    $fmt = new IntlDateFormatter('pt_PT', IntlDateFormatter::LONG, IntlDateFormatter::NONE);
    $data_envio = $fmt->format(new DateTime());
}

// ============================================================================
// EMAIL BODY TEMPLATE
// ============================================================================
$email_body = "Ex.mo(a) Senhor(a),\n\n"
    . "No âmbito do processo de verificação e reporte periódico do funcionamento dos serviços "
    . "dos conjuntos de dados abertos publicados no Registo Nacional dos Dados Geográficos do SNIG, "
    . "envia-se em anexo o relatório dos testes de funcionamento e qualidade dos serviços publicados "
    . "no SNIG pela sua entidade, realizados a $data_envio.\n\n"
    . "Agradecemos a sua intervenção em conformidade para corrigir com a maior celeridade possível "
    . "os eventuais problemas e assim assegurar a utilização dos respetivos serviços publicados de forma "
    . "contínua e permanente pelos cidadãos, entidades e empresas.\n\n"
    . "No caso de verificar que o serviço está a funcionar corretamente e não consiga replicar o erro, "
    . "agradecemos que nos contacte com a identificação explicita do erro, teste e serviço.\n\n"
    . "Com os melhores cumprimentos,\nA equipa SNIG/INSPIRE.";

// ============================================================================
// PREPARE OUTPUT DIRECTORY
// ============================================================================
if (!is_dir($report_dir_pdf)) {
    mkdir($report_dir_pdf, 0775, true);
}

// ============================================================================
// DATABASE CONNECTION
// ============================================================================
$conn = pg_connect("host=$dbhost dbname=$dbname user=$dbuser port=$dbport");

if (!$conn) {
    die("❌ Could not connect to PostgreSQL\n");
}

// ============================================================================
// FETCH ENTITIES WITH EMAILS
// ============================================================================
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

// ============================================================================
// PROCESS EACH ENTITY
// ============================================================================
while ($row = pg_fetch_assoc($result)) {

    $gid    = $row['gid'];
    $entity = $row['entity'];
    $email  = trim($row['email']);
    $eid    = $row['eid'];

    // ------------------------------------------------------------------------
    // LOCATE HTML REPORT FILES
    // ------------------------------------------------------------------------
    $pattern_old = sprintf('%s/%s_*.html', $report_dir_html, $eid);
    $pattern_new = sprintf(
        '%s/%s_*_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].html',
        $report_dir_html,
        $eid
    );

    $html_files = array_merge(glob($pattern_new), glob($pattern_old));

    if (empty($html_files)) {
        echo "⚠️ No HTML found for eid {$eid} ({$entity})\n";
        continue;
    }

    // Sort HTML files by modification date (latest first)
    usort($html_files, function ($a, $b) {
        return filemtime($b) <=> filemtime($a);
    });

    $html_file = $html_files[0];

    // Extract date suffix from filename
    if (preg_match('/_(\d{8})\.html$/', basename($html_file), $m)) {
        $date_suffix = '_' . $m[1];
    } else {
        $date_suffix = '';
    }

    // Generate PDF file path
    $pdf_file = sprintf(
        '%s/%s_%s%s.pdf',
        $report_dir_pdf,
        $eid,
        preg_replace('/[\/ ]+/', '_', $entity),
        $date_suffix
    );

    // ------------------------------------------------------------------------
    // GENERATE PDF USING MPDF
    // ------------------------------------------------------------------------
    try {
        $html_content = file_get_contents($html_file);

        $mpdf = new Mpdf(['tempDir' => sys_get_temp_dir()]);

        // Split WriteHTML into chunks if HTML is large
        foreach (str_split($html_content, 1000000) as $chunk) {
            $mpdf->WriteHTML($chunk);
        }

        $mpdf->Output($pdf_file, \Mpdf\Output\Destination::FILE);
        echo "✅ PDF generated: {$pdf_file}\n";

    } catch (Exception $e) {
        echo "❌ PDF generation failed for {$entity}: " . $e->getMessage() . "\n";
        continue;
    }

    // ------------------------------------------------------------------------
    // SEND EMAIL WITH PDF ATTACHMENT
    // ------------------------------------------------------------------------
    try {
        $subject_date = "Relatório de funcionamento e qualidade dos serviços publicados no SNIG: $data_envio";

        $mail = new PHPMailer(true);
        $mail->isSMTP();
        $mail->Host     = $smtp_host;
        $mail->Port     = $smtp_port;
        $mail->SMTPAuth = false;

        $mail->CharSet  = 'UTF-8';
        $mail->Encoding = 'base64';

        $mail->setFrom($email_from, 'Direção-Geral do Território');
        $mail->addAddress($email);
        $mail->addBCC('rpinho@dgterritorio.pt');
        $mail->Subject = $subject_date;
        $mail->Body    = $email_body;
        $mail->addAttachment($pdf_file);

        $mail->send();
        echo "📨 Email sent to {$email} ({$entity})\n";

    } catch (Exception $e) {
        echo "❌ Failed to send email to {$email}: " . $mail->ErrorInfo . "\n";
    }
}

// ============================================================================
// CLEANUP
// ============================================================================
pg_close($conn);
echo "\nRelatórios PDF processados.\n";
