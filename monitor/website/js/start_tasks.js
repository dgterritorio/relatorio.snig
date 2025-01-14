/*
 *  this is meant to be a rvt template. It requires the following variables to be defined
 *
 *   * service_gid: gid of a service record
 *
 * Requirements:
 * 
 *   + Beforehand function check_job to have been load
 *   + Must include check_job.js which defines function
 *     check_job and the variable checkJobTimer
 *   + The caller must have a text element with id #response
 */

<?
    ::rivet::parse js/check_job.js
?>

function start_tasks () {
    // Disable the button to prevent multiple clicks
    $(this).prop('disabled', true).text('Waiting for response...');

    // Send AJAX request to the server
    $.ajax({
        url:    '<?= [::rivetweb::composeUrl cmd CHECK var1 $service_gid] ?>', 
        method: 'GET',           // HTTP method (GET, POST, etc.)
        dataType: 'json',        // Expected response type
        success: function (response) {
            // Update the UI based on the response
            $('#response').text(response.message);
            checkJobTimer = setInterval(check_job,1000);
        },
        error: function (jqXHR, textStatus, errorThrown) {
            // Handle errors
            $('#response').text('Error: ' + textStatus);
        },
        complete: function () {
            // Re-enable the button after the request completes
            // $('#start_job').prop('disabled', false).text('Start Checks');
        }
    });
}
