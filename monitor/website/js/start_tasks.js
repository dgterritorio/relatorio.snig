/*
 *  this is meant to be a rvt template. It requires the following variables to be defined
 *
 *   * service_gid: gid of a service record
 *
 * Requirements:
 * 
 *   * Beforehand function check_job to have been load
 */

var checkJobTimer;

function check_job (msdelay) {

    $.ajax(
    {
        url:    '<?= [::rivetweb::composeUrl cmd JOBLIST] ?>', 
        method: 'GET',           // HTTP method (GET, POST, etc.)
        dataType: 'json',        // Expected response type
        success: function (response) {
            // Update the UI based on the response
            if (response.njobs > 0)
            {
                for (var key in response.jobs) {
                    if (json.hasOwnProperty(key)) {
                        if {json.message[key].gid == <?= $service_gid ?>} {
                            $('#response').text('Job running task ' + json.message[key].status);
                        } else {
                            clearTimeout(checkJobTimer);
                        }
                    }
                }
            } else {
                $('#response').text(response.message);
            }
        },
        error: function (jqXHR, textStatus, errorThrown) {
            // Handle errors
            $('#response').text('Error: ' + textStatus);
        },
        complete: function () {
            // Re-enable the button after the request completes
            $('#start_job').prop('disabled', false).text('Start Checks');
        }
    });

}

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
            $('#start_job').prop('disabled', false).text('Start Checks');
        }
    });
}
