/*
 *  this is meant to be a rvt template. It requires the following variables to be defined
 *
 *   * service_gid: gid of a service record
 *
 * Requirements:
 *
 *  It needs to element to be defined in the DOM
 *
 *      + 
 *      +
 */

var checkJobTimer;

function check_job (msdelay) {

    $.ajax(
    {
        url:        '<?= [::rivetweb::composeUrl cmd JOBLIST] ?>', 
        method:     'GET',              // HTTP method (GET, POST, etc.)
        dataType:   'json',             // Expected response type
        success: function (response) {
            // Update the UI based on the response
            if (response.njobs > 0)
            {
                var service_is_being_checked = false;
                for (var idx in response.jobs) {
                    job = response.jobs[idx];
                    if (job.gid == <?= $service_gid ?>) {
                        $('#start_job').prop('disabled', true).text('Job Running...');
                        $('#response').html('<span>Job running task ' + '<span class="task_highlight">' + job.status + '</span></span>');
                        service_is_being_checked = true;
                        break;
                    }
                }
                if (!service_is_being_checked) {
                    clearTimeout(checkJobTimer);
                    do_refresh();
                    $('#response').text('');
                    $('#start_job').prop('disabled', false).text('Start Checks');
                }

            } else {
                clearTimeout(checkJobTimer);
                do_refresh();
                $('#response').text('');
                $('#start_job').prop('disabled', false).text('Start Checks');
            }
        },
        error: function (jqXHR, textStatus, errorThrown) {
            // Handle errors
            $('#response').text('Error: ' + textStatus);
        },
        complete: function () {
            // Re-enable the button after the request completes
            //$('#start_job').prop('disabled', false).text('Start Checks');
        }
    });

}
