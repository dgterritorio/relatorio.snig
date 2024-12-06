
$(window).on("load",function() {
    $.ajax({
        url:        '<?= [::rivetweb::composeUrl report $report_n] ?>', 
        method:     'GET',     // HTTP method (GET, POST, etc.)
        dataType:   'json',    // Expected response type
        success: function (response) {
            // Update the UI based on the response
            $('#report').text(response.report);
            // $('#response').text(response.nconnections + ' active connections');
        },
        error: function (jqXHR, textStatus, errorThrown) {
            // Handle errors
            $('#response').text('Error: ' + textStatus);
        },
        complete: function () {
        }
    });
});
