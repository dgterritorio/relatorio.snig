/*
 *  this is meant to be a rvt template. It requires the following variables to be defined
 *
 *   * service_gid: gid of a service record
 */

function do_refresh () {
    // Disable the button to prevent multiple clicks
    $(this).prop('disabled', true).text('Waiting for response...');

    // Send AJAX request to the server
    $.ajax({
        url:    '<?= [::rivetweb::composeUrl report 118 gid $service_gid] ?>', 
        method: 'GET',           // HTTP method (GET, POST, etc.)
        dataType: 'json',        // Expected response type
        success: function (response) {
            // Update the UI based on the response
            $('#response').text(response.title);
            $('#task_results').html(response.report);
        },
        error: function (jqXHR, textStatus, errorThrown) {
            // Handle errors
            $('#response').text('Error: ' + textStatus);
        },
        complete: function () {
            // Re-enable the button after the request completes
            $('#refresh').prop('disabled', false).text('Refresh');
        }
    });
}


