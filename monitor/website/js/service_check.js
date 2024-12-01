<?
set service_id [$::rivetweb::current_page service_gid]
?>

function start_tasks () {
    // Disable the button to prevent multiple clicks
    $(this).prop('disabled', true).text('Waiting for response...');

    // Send AJAX request to the server
    $.ajax({
        url:    'http://ngis.rivetweb.org:8080/index.rvt?cmd=CHECK&var1=<?= $service_id ?>', 
        method: 'GET',           // HTTP method (GET, POST, etc.)
        dataType: 'json',        // Expected response type
        success: function (response) {
            // Update the UI based on the response
            $('#response').text(response.message);
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

function do_refresh () {
    // Disable the button to prevent multiple clicks
    $(this).prop('disabled', true).text('Waiting for response...');

    // Send AJAX request to the server
    $.ajax({
        url:    'http://ngis.rivetweb.org:8080/index.rvt?report=118&gid=<?= $service_id ?>', 
        method: 'GET',           // HTTP method (GET, POST, etc.)
        dataType: 'json',        // Expected response type
        success: function (response) {
            // Update the UI based on the response
            $('#response').text(response.message);
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

$(document).ready(function () {
    $('#start_job').click(start_tasks);
    $('#refresh').click(do_refresh);
});

