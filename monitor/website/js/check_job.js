/*
 *  this is meant to be a rvt template. It requires the following variables to be defined
 *
 *   * service_gid: gid of a service record
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
